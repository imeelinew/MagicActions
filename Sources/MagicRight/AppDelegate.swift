import AppKit
import SwiftUI

private let finderSyncBundleIdentifier = "local.elidev.MagicRight.FinderSync"

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let notificationSeconds: TimeInterval = 5
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private lazy var mainWindowController = MagicRightWindowController()
    private var notificationPopover: NSPopover?
    private var notificationDismissWorkItem: DispatchWorkItem?
    private var eventReadWorkItem: DispatchWorkItem?
    private var lastPopoverEventContent = ""
    private var eventSource: DispatchSourceFileSystemObject?
    private var eventDirectoryDescriptor: CInt = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
        configureStatusItem()
        installApplicationScripts()
        startPopoverEventWatcher()
    }

    private func installMainMenu() {
        let mainMenu = NSMenu(title: "MainMenu")

        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: "MagicRight")
        appMenu.addItem(
            withTitle: "关于 MagicRight",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "退出 MagicRight",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "文件")
        fileMenu.addItem(
            withTitle: "关闭窗口",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        NSApp.mainMenu = mainMenu
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "pointer.arrow.ipad.rays",
            accessibilityDescription: "MagicRight"
        ) ?? NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "MagicRight")
        button.image?.isTemplate = true
        button.toolTip = "MagicRight"
        statusItem.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu(title: "MagicRight")

        menu.addItem(
            withTitle: "打开 MagicRight",
            action: #selector(showMainWindow),
            keyEquivalent: "o"
        )
        menu.addItem(
            withTitle: "退出",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        return menu
    }

    private func installApplicationScripts() {
        guard let resourceURL = Bundle.main.resourceURL else {
            NSLog("[MagicRight] Missing bundle resources")
            return
        }

        let scriptsSource = resourceURL.appendingPathComponent("Scripts", isDirectory: true)
        let templatesSource = resourceURL.appendingPathComponent("Templates", isDirectory: true)
        let scriptsDestination = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Scripts/\(finderSyncBundleIdentifier)", isDirectory: true)

        do {
            try syncManagedDirectoryContents(from: scriptsSource, to: scriptsDestination, executable: true)
            try syncManagedDirectoryContents(from: templatesSource, to: scriptsDestination, executable: false)
            removeLegacyMoveState()
            MenuActionConfiguration.writeEnabledIDs(MenuActionConfiguration.enabledIDs())
            NSLog("[MagicRight] Installed scripts to \(scriptsDestination.path)")
        } catch {
            NSLog("[MagicRight] Failed to install scripts: \(error)")
        }
    }

    private func removeLegacyMoveState() {
        let stateDirectory = FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/MagicRight", isDirectory: true)
        try? FileManager.default.removeItem(at: stateDirectory)
    }

    private var scriptsDirectoryURL: URL {
        FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Scripts/\(finderSyncBundleIdentifier)", isDirectory: true)
    }

    private var popoverEventURL: URL {
        scriptsDirectoryURL.appendingPathComponent("popover-event.txt")
    }

    private func startPopoverEventWatcher() {
        do {
            try FileManager.default.createDirectory(at: scriptsDirectoryURL, withIntermediateDirectories: true)
        } catch {
            NSLog("[MagicRight] Failed to create scripts directory for popover watcher: \(error)")
            return
        }

        eventDirectoryDescriptor = open(scriptsDirectoryURL.path, O_EVTONLY)
        guard eventDirectoryDescriptor >= 0 else {
            NSLog("[MagicRight] Failed to watch popover event directory")
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: eventDirectoryDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.schedulePopoverEventRead()
        }
        source.setCancelHandler { [weak self] in
            guard let self, self.eventDirectoryDescriptor >= 0 else { return }
            close(self.eventDirectoryDescriptor)
            self.eventDirectoryDescriptor = -1
        }
        eventSource = source
        source.resume()
    }

    private func schedulePopoverEventRead() {
        eventReadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.readPopoverEvent()
        }
        eventReadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func readPopoverEvent() {
        guard let content = try? String(contentsOf: popoverEventURL, encoding: .utf8) else {
            return
        }
        guard content != lastPopoverEventContent else {
            return
        }
        lastPopoverEventContent = content

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.count >= 3 else { return }

        let kind: MenuBarNotificationView.Kind = lines[0] == "error" ? .error : .success
        let actionID: String
        let title: String
        let subtitle: String
        if lines.count >= 4 {
            actionID = lines[1]
            title = lines[2]
            subtitle = lines[3]
        } else {
            actionID = "generic"
            title = lines[1]
            subtitle = lines[2]
        }
        showMenuBarPopover(title: title, subtitle: subtitle, actionID: actionID, kind: kind)
    }

    private func showMenuBarPopover(
        title: String,
        subtitle: String,
        actionID: String,
        kind: MenuBarNotificationView.Kind
    ) {
        guard let button = statusItem.button else { return }

        notificationDismissWorkItem?.cancel()
        notificationPopover?.close()

        let hosting = NSHostingController(
            rootView: MenuBarNotificationView(title: title, subtitle: subtitle, actionID: actionID, kind: kind)
        )
        hosting.view.frame = NSRect(x: 0, y: 0, width: 280, height: 200)
        hosting.view.layoutSubtreeIfNeeded()
        let fitted = hosting.view.fittingSize

        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = hosting
        popover.contentSize = NSSize(width: 280, height: fitted.height)
        notificationPopover = popover

        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        DispatchQueue.main.async {
            popover.contentViewController?.view.window?.makeKey()
        }

        let work = DispatchWorkItem { [weak self] in
            self?.notificationPopover?.close()
        }
        notificationDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + notificationSeconds, execute: work)
    }

    private func syncManagedDirectoryContents(from source: URL, to destination: URL, executable: Bool) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: source.path) else { return }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        let itemURLs = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        let sourceNames = Set(itemURLs.map(\.lastPathComponent))

        if executable {
            let destinationURLs = try fileManager.contentsOfDirectory(
                at: destination,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for destinationURL in destinationURLs
                where destinationURL.pathExtension == "sh" && !sourceNames.contains(destinationURL.lastPathComponent) {
                try fileManager.removeItem(at: destinationURL)
            }
        }

        for itemURL in itemURLs {
            let targetURL = destination.appendingPathComponent(itemURL.lastPathComponent)
            if fileManager.fileExists(atPath: targetURL.path),
               !fileManager.contentsEqual(atPath: itemURL.path, andPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
                try fileManager.copyItem(at: itemURL, to: targetURL)
            } else if !fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.copyItem(at: itemURL, to: targetURL)
            }
            if executable {
                try fileManager.setAttributes(
                    [.posixPermissions: NSNumber(value: Int16(0o755))],
                    ofItemAtPath: targetURL.path
                )
            }
        }
    }

    @objc private func showMainWindow() {
        mainWindowController.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
