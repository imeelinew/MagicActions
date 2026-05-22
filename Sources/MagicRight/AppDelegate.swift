import AppKit

private let finderSyncBundleIdentifier = "local.elidev.MagicRight.FinderSync"

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private lazy var mainWindowController = MagicRightWindowController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installMainMenu()
        configureStatusItem()
        installApplicationScripts()
        mainWindowController.show()
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

        let titleItem = NSMenuItem(title: "MagicRight", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        let readyItem = NSMenuItem(title: "Finder 扩展已就绪", action: nil, keyEquivalent: "")
        readyItem.isEnabled = false
        menu.addItem(readyItem)

        menu.addItem(.separator())
        menu.addItem(
            withTitle: "打开 MagicRight",
            action: #selector(showMainWindow),
            keyEquivalent: "o"
        )
        menu.addItem(
            withTitle: "退出 MagicRight",
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
            try syncDirectory(from: scriptsSource, to: scriptsDestination, executable: true)
            try copyDirectoryContents(from: templatesSource, to: scriptsDestination, executable: false)
            MenuActionConfiguration.writeEnabledIDs(MenuActionConfiguration.enabledIDs())
            NSLog("[MagicRight] Installed scripts to \(scriptsDestination.path)")
        } catch {
            NSLog("[MagicRight] Failed to install scripts: \(error)")
        }
    }

    private func syncDirectory(from source: URL, to destination: URL, executable: Bool) throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        try copyDirectoryContents(from: source, to: destination, executable: executable)
    }

    private func copyDirectoryContents(from source: URL, to destination: URL, executable: Bool) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: source.path) else { return }
        let itemURLs = try fileManager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for itemURL in itemURLs {
            let targetURL = destination.appendingPathComponent(itemURL.lastPathComponent)
            if fileManager.fileExists(atPath: targetURL.path) {
                try fileManager.removeItem(at: targetURL)
            }
            try fileManager.copyItem(at: itemURL, to: targetURL)
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
