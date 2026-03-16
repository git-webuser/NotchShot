import AppKit
import SwiftUI



// MARK: - Screenshot-style crosshair cursor

/// Воспроизводит системный screenshot crosshair (Shift+Cmd+4) как кастомный NSCursor.
/// Рисуется программно: 4 линии 1×11pt от центра, 1pt белый центральный пиксель.
private func makeScreenshotCrosshairCursor() -> NSCursor {
    let size: CGFloat = 24

    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return .crosshair
    }

    ctx.scaleBy(x: 1, y: -1)
    ctx.translateBy(x: 0, y: -size)

    let cx = size / 2, cy = size / 2
    let armLen:  CGFloat = 11
    let thick:   CGFloat = 1.0   // толщина линий как у iBeam
    let outline: CGFloat = 1.0   // белая обводка с каждой стороны
    let gap:     CGFloat = 0.5   // зазор у центра — убирает артефакт пересечения

    let arms: [CGRect] = [
        CGRect(x: cx - thick/2, y: cy - armLen, width: thick, height: armLen - gap),
        CGRect(x: cx - thick/2, y: cy + gap,    width: thick, height: armLen - gap),
        CGRect(x: cx - armLen,  y: cy - thick/2, width: armLen - gap, height: thick),
        CGRect(x: cx + gap,     y: cy - thick/2, width: armLen - gap, height: thick),
    ]

    // Белая обводка — чистая, как у iBeam и других системных курсоров
    ctx.setFillColor(NSColor(white: 1.0, alpha: 0.6).cgColor)
    for arm in arms {
        ctx.fill(arm.insetBy(dx: -outline, dy: -outline))
    }
    ctx.fill(CGRect(
        x: cx - thick/2 - outline, y: cy - thick/2 - outline,
        width: thick + outline * 2, height: thick + outline * 2
    ))

    // Основные линии — чёрные
    ctx.setFillColor(NSColor.black.cgColor)
    for arm in arms {
        ctx.fill(arm)
    }

    // Центральный пиксель белый
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: cx - thick/2, y: cy - thick/2, width: thick, height: thick))

    image.unlockFocus()

    return NSCursor(image: image, hotSpot: NSPoint(x: size / 2, y: size / 2))
}

// MARK: - FullscreenTrackingView

private final class FullscreenTrackingView: NSView {

    var onMouseMoved: ((NSPoint) -> Void)?

    private lazy var screenshotCursor = makeScreenshotCrosshairCursor()

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate],
            owner: self,
            userInfo: nil
        ))
    }

    override func cursorUpdate(with event: NSEvent) {
        screenshotCursor.set()
    }

    override func mouseMoved(with event: NSEvent) {
        screenshotCursor.set()
        guard let win = window else { return }
        let pos = NSPoint(
            x: event.locationInWindow.x + win.frame.minX,
            y: event.locationInWindow.y + win.frame.minY
        )
        onMouseMoved?(pos)
    }

    override func mouseEntered(with event: NSEvent) {
        screenshotCursor.set()
    }

    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override var acceptsFirstResponder: Bool { true }
}

// MARK: - FullscreenCursorWindow

private final class FullscreenCursorWindow: NSPanel {
    override var canBecomeKey: Bool  { true  }
    override var canBecomeMain: Bool { false }
}

// MARK: - CursorOverlay

/// Overlay с кастомным crosshair-курсором.
///
/// Скрытие системного курсора: прозрачный NSCursor переустанавливается на
/// каждый mouseMoved. Никакого NSCursor.hide/unhide — только .set().
@MainActor
final class CursorOverlay {

    private var fullscreenWindow: FullscreenCursorWindow?
    private var currentColor: NSColor? = nil

    var onMouseMoved: ((NSPoint) -> Void)?

    // MARK: - Public API

    /// Вызывается при выборе "Pick Color" в меню.
    /// Подписывается на NSMenu.didEndTrackingNotification и устанавливает
    /// прозрачный курсор как только меню гарантированно закрылось.
    /// macOS восстанавливает курсор при закрытии меню, поэтому нельзя
    /// просто вызвать .set() раньше — нужно дождаться конца трекинга.
    static func hideCursorAfterMenuCloses() {
        nonisolated(unsafe) var token: NSObjectProtocol?
        token = NotificationCenter.default.addObserver(
            forName: NSMenu.didEndTrackingNotification,
            object: nil, queue: .main
        ) { _ in
            if let t = token { NotificationCenter.default.removeObserver(t); token = nil }
            DispatchQueue.main.async {
                DispatchQueue.main.async { makeScreenshotCrosshairCursor().set() }
            }
        }
    }

        func show() {
        let cursorPos = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorPos) }) ?? NSScreen.main ?? NSScreen.screens[0]
        ensureFullscreenWindow(on: screen)
        installGlobalMouseMonitor()
        guard let fw = fullscreenWindow else { return }
        fw.orderFrontRegardless()
        fw.makeKey()
        DispatchQueue.main.async { makeScreenshotCrosshairCursor().set() }
    }

        func move(to position: NSPoint) { }

        func updateColor(_ color: NSColor?) { }

        func hide() {
        fullscreenWindow?.orderOut(nil)
        removeGlobalMouseMonitor()
        NSCursor.arrow.set()
    }

    // MARK: - Private

    /// Глобальный монитор движения мыши — покрывает все дисплеи,
    /// включая те на которых нет FullscreenTrackingView.
    private var globalMouseMonitor: Any?

    private func installGlobalMouseMonitor() {
        guard globalMouseMonitor == nil else { return }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged]
        ) { [weak self] _ in
            guard let self else { return }
            let pos = NSEvent.mouseLocation
            DispatchQueue.main.async {
                self.move(to: pos)
                self.onMouseMoved?(pos)
            }
        }
    }

    private func removeGlobalMouseMonitor() {
        if let m = globalMouseMonitor {
            NSEvent.removeMonitor(m)
            globalMouseMonitor = nil
        }
    }




    private func ensureFullscreenWindow(on screen: NSScreen) {
        if let fw = fullscreenWindow {
            fw.setFrame(screen.frame, display: false)
            return
        }
        let fw = FullscreenCursorWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        fw.isFloatingPanel    = true
        fw.level              = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.cursorWindow)) - 2)
        fw.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        fw.isOpaque           = false
        fw.backgroundColor    = .clear
        fw.hasShadow          = false
        fw.hidesOnDeactivate  = false
        fw.ignoresMouseEvents = false
        fw.appearance         = NSAppearance(named: .darkAqua)

        let trackingView = FullscreenTrackingView(frame: screen.frame)
        trackingView.wantsLayer = true
        trackingView.layer?.backgroundColor = CGColor.clear
        trackingView.onMouseMoved = { [weak self] pos in
            guard let self else { return }
            self.move(to: pos)
            self.onMouseMoved?(pos)
        }
        fw.contentView = trackingView
        self.fullscreenWindow = fw
    }


}
