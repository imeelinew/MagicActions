import AppKit
import ApplicationServices
import Carbon

@MainActor
final class WindowOperationManager {
    private enum HotKey: UInt32 {
        case left = 1
        case right = 2
        case up = 3
        case down = 4
    }

    private struct WindowFrame {
        let position: CGPoint
        let size: CGSize
    }

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var previousFrames: [String: WindowFrame] = [:]

    func start() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return status }

            let manager = Unmanaged<WindowOperationManager>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in
                manager.handleHotKey(id: hotKeyID.id)
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        register(keyCode: UInt32(kVK_LeftArrow), id: .left)
        register(keyCode: UInt32(kVK_RightArrow), id: .right)
        register(keyCode: UInt32(kVK_UpArrow), id: .up)
        register(keyCode: UInt32(kVK_DownArrow), id: .down)
    }

    func stop() {
        for hotKeyRef in hotKeyRefs {
            if let hotKeyRef {
                UnregisterEventHotKey(hotKeyRef)
            }
        }
        hotKeyRefs.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
        previousFrames.removeAll()
    }

    private func register(keyCode: UInt32, id: HotKey) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: fourCharCode("MgRt"), id: id.rawValue)
        RegisterEventHotKey(
            keyCode,
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        hotKeyRefs.append(hotKeyRef)
    }

    private func handleHotKey(id: UInt32) {
        guard WindowOperationConfiguration.isEnabled() else { return }
        guard AXIsProcessTrusted() else { return }
        guard let hotKey = HotKey(rawValue: id) else { return }
        guard let target = focusedWindow() else { return }

        switch hotKey {
        case .left:
            move(target, to: .leftHalf)
        case .right:
            move(target, to: .rightHalf)
        case .up:
            move(target, to: .maximized)
        case .down:
            restore(target)
        }
    }

    private enum WindowLayout {
        case leftHalf
        case rightHalf
        case maximized
    }

    private func move(_ target: WindowTarget, to layout: WindowLayout) {
        guard let currentFrame = readFrame(target.window) else { return }
        let screenFrame = screenFrame(containing: currentFrame)

        let newFrame: WindowFrame
        switch layout {
        case .leftHalf:
            newFrame = WindowFrame(
                position: CGPoint(x: screenFrame.minX, y: topLeftY(for: screenFrame)),
                size: CGSize(width: floor(screenFrame.width / 2), height: screenFrame.height)
            )
        case .rightHalf:
            let width = ceil(screenFrame.width / 2)
            newFrame = WindowFrame(
                position: CGPoint(x: screenFrame.maxX - width, y: topLeftY(for: screenFrame)),
                size: CGSize(width: width, height: screenFrame.height)
            )
        case .maximized:
            newFrame = WindowFrame(
                position: CGPoint(x: screenFrame.minX, y: topLeftY(for: screenFrame)),
                size: screenFrame.size
            )
        }

        previousFrames[target.identifier] = currentFrame
        apply(newFrame, to: target.window)
    }

    private func restore(_ target: WindowTarget) {
        guard let previousFrame = previousFrames.removeValue(forKey: target.identifier) else { return }
        apply(previousFrame, to: target.window)
    }

    private struct WindowTarget {
        let window: AXUIElement
        let identifier: String
    }

    private func focusedWindow() -> WindowTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        let window =
            elementValue(for: kAXFocusedWindowAttribute, element: appElement)
            ?? elementValue(for: kAXMainWindowAttribute, element: appElement)
            ?? arrayValue(for: kAXWindowsAttribute, element: appElement)?.first

        guard let window else { return nil }
        return WindowTarget(window: window, identifier: "\(app.processIdentifier)-\(CFHash(window))")
    }

    private func readFrame(_ window: AXUIElement) -> WindowFrame? {
        guard
            let position = pointValue(for: kAXPositionAttribute, element: window),
            let size = sizeValue(for: kAXSizeAttribute, element: window)
        else { return nil }

        return WindowFrame(position: position, size: size)
    }

    private func apply(_ frame: WindowFrame, to window: AXUIElement) {
        var position = frame.position
        var size = frame.size

        if let positionValue = AXValueCreate(.cgPoint, &position) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)
        }
        if let sizeValue = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        }
    }

    private func screenFrame(containing frame: WindowFrame) -> CGRect {
        let center = CGPoint(
            x: frame.position.x + (frame.size.width / 2),
            y: frame.position.y + (frame.size.height / 2)
        )

        return NSScreen.screens
            .first { screen in screen.globalTopLeftFrame.contains(center) }?
            .globalTopLeftVisibleFrame
            ?? NSScreen.main?.globalTopLeftVisibleFrame
            ?? .zero
    }

    private func topLeftY(for globalVisibleFrame: CGRect) -> CGFloat {
        globalVisibleFrame.minY
    }

    private func elementValue(for key: String, element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, key as CFString, &value)
        guard result == .success else { return nil }
        return (value as! AXUIElement)
    }

    private func arrayValue(for key: String, element: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, key as CFString, &value)
        guard result == .success else { return nil }
        return value as? [AXUIElement]
    }

    private func pointValue(for key: String, element: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, key as CFString, &value)
        guard result == .success, let axValue = value else { return nil }

        let pointValue = axValue as! AXValue
        guard AXValueGetType(pointValue) == .cgPoint else { return nil }

        var point = CGPoint.zero
        AXValueGetValue(pointValue, .cgPoint, &point)
        return point
    }

    private func sizeValue(for key: String, element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, key as CFString, &value)
        guard result == .success, let axValue = value else { return nil }

        let sizeValue = axValue as! AXValue
        guard AXValueGetType(sizeValue) == .cgSize else { return nil }

        var size = CGSize.zero
        AXValueGetValue(sizeValue, .cgSize, &size)
        return size
    }
}

private extension NSScreen {
    var globalTopLeftFrame: CGRect {
        guard let displayID else { return frame }
        return CGDisplayBounds(displayID)
    }

    var globalTopLeftVisibleFrame: CGRect {
        guard let displayID else { return visibleFrame }
        let displayBounds = CGDisplayBounds(displayID)
        let bottomInset = visibleFrame.minY - frame.minY
        let topInset = frame.maxY - visibleFrame.maxY

        return CGRect(
            x: displayBounds.minX + (visibleFrame.minX - frame.minX),
            y: displayBounds.minY + topInset,
            width: visibleFrame.width,
            height: visibleFrame.height
        )
    }

    private var displayID: CGDirectDisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return CGDirectDisplayID(number.uint32Value)
    }
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
}
