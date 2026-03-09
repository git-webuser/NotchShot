import AppKit
import CoreGraphics
import Carbon

final class NotchHoverController: NSObject {
    private let panel: NotchPanelController

    private var statusItem: NSStatusItem?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyHandlerRef: EventHandlerRef?

    // Control + Option + Command + N
    private let hotKeyCode: UInt32 = UInt32(kVK_ANSI_N)
    private let hotKeyModifiers: UInt32 = UInt32(controlKey | optionKey | cmdKey)

    init(panel: NotchPanelController) {
        self.panel = panel
        super.init()
    }

    deinit {
        stop()
    }

    func start() {
        stop()
        installStatusItem()
        installHotKey()
        installEventTap()
    }

    func stop() {
        uninstallEventTap()
        uninstallHotKey()
        uninstallStatusItem()
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        guard let button = item.button else { return }
        button.image = NSImage(systemSymbolName: "camera", accessibilityDescription: "NotchShot")
        button.imagePosition = .imageOnly
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp])
    }

    private func uninstallStatusItem() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    @objc
    private func statusItemClicked() {
        let screen = preferredScreenForOpen()
        panel.toggleAnimated(on: screen)
    }

    private func installHotKey() {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let callback: EventHandlerUPP = { _, eventRef, userData in
            guard let userData, let eventRef else { return noErr }

            let controller = Unmanaged<NotchHoverController>.fromOpaque(userData).takeUnretainedValue()
            var incomingHotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &incomingHotKeyID
            )
            guard status == noErr else { return noErr }

            controller.handleHotKey(incomingHotKeyID)
            return noErr
        }

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &hotKeyHandlerRef
        )
        guard handlerStatus == noErr else { return }

        let hotKeyID = EventHotKeyID(signature: fourCharCode("NTSH"), id: 1)
        let registerStatus = RegisterEventHotKey(
            hotKeyCode,
            hotKeyModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if registerStatus != noErr {
            hotKeyRef = nil
        }
    }

    private func uninstallHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let hotKeyHandlerRef {
            RemoveEventHandler(hotKeyHandlerRef)
            self.hotKeyHandlerRef = nil
        }
    }

    private func handleHotKey(_ hotKeyID: EventHotKeyID) {
        guard hotKeyID.id == 1 else { return }
        let screen = preferredScreenForOpen()
        panel.toggleAnimated(on: screen)
    }

    private func installEventTap() {
        let mask = (1 << CGEventType.leftMouseDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }

            let controller = Unmanaged<NotchHoverController>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = controller.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .leftMouseDown else {
                return Unmanaged.passUnretained(event)
            }

            DispatchQueue.main.async {
                controller.handleGlobalLeftMouseDown()
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            return
        }

        self.eventTap = tap
        self.eventTapSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func uninstallEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.eventTapSource = nil
        }
        self.eventTap = nil
    }

    private func handleGlobalLeftMouseDown() {
        let mouse = NSEvent.mouseLocation
        guard let screen = screenForPoint(mouse) else { return }
        guard screen.notchGapWidth > 0 else { return }

        let trigger = triggerRect(on: screen)
        guard !trigger.isNull else { return }

        if panel.isVisible {
            if panel.suppressesGlobalAutoHide {
                return
            }
            if trigger.contains(mouse) {
                panel.hideAnimated()
                return
            }
            if !panel.isPointInsidePanel(mouse) {
                panel.hideAnimated()
            }
            return
        }

        if trigger.contains(mouse) {
            panel.showAnimated(on: screen)
        }
    }

    private func preferredScreenForOpen() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return screenForPoint(mouse) ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func screenForPoint(_ p: NSPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(p) }) ?? NSScreen.main
    }

    private func triggerRect(on screen: NSScreen) -> CGRect {
        let sf = screen.frame
        let vf = screen.visibleFrame
        let notchWidth = screen.notchGapWidth
        guard notchWidth > 0 else { return .null }

        let menuBarHeight = max(0, sf.maxY - vf.maxY)
        guard menuBarHeight > 0 else { return .null }

        let horizontalHitInset: CGFloat = 12
        let width = notchWidth + horizontalHitInset * 2
        let x = sf.midX - width / 2
        let y = vf.maxY
        return CGRect(x: x, y: y, width: width, height: menuBarHeight)
    }
}

private func fourCharCode(_ string: String) -> OSType {
    precondition(string.utf16.count == 4, "Hotkey signature must be 4 characters")
    return string.utf16.reduce(0) { partial, scalar in
        (partial << 8) + OSType(scalar)
    }
}
