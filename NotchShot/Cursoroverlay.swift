import AppKit
import SwiftUI

// MARK: - CursorOverlayView

private struct CursorOverlayView: View {
    let color: NSColor?

    private let size:       CGFloat = 22
    private let gapRadius:  CGFloat = 3
    private let lineLength: CGFloat = 6
    private let lineWidth:  CGFloat = 1.5

    var body: some View {
        ZStack {
            crosshairShape(inset: 0.5).stroke(shadowColor,     lineWidth: lineWidth + 1)
            crosshairShape(inset: 0  ).stroke(foregroundColor, lineWidth: lineWidth)
        }
        .frame(width: size, height: size)
    }

    private func crosshairShape(inset: CGFloat) -> some Shape {
        CrosshairShape(size: size, gapRadius: gapRadius + inset, lineLength: lineLength - inset)
    }

    private var foregroundColor: Color {
        guard let c = color?.usingColorSpace(.sRGB) else { return .white }
        let lum = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        return lum > 0.55 ? .black : .white
    }

    private var shadowColor: Color {
        guard let c = color?.usingColorSpace(.sRGB) else { return .black }
        let lum = 0.299 * c.redComponent + 0.587 * c.greenComponent + 0.114 * c.blueComponent
        return lum > 0.55 ? Color.white.opacity(0.6) : Color.black.opacity(0.6)
    }
}

// MARK: - CrosshairShape

private struct CrosshairShape: Shape {
    let size: CGFloat
    let gapRadius: CGFloat
    let lineLength: CGFloat

    func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy - gapRadius))
        p.addLine(to: CGPoint(x: cx, y: cy - gapRadius - lineLength))
        p.move(to: CGPoint(x: cx, y: cy + gapRadius))
        p.addLine(to: CGPoint(x: cx, y: cy + gapRadius + lineLength))
        p.move(to: CGPoint(x: cx - gapRadius, y: cy))
        p.addLine(to: CGPoint(x: cx - gapRadius - lineLength, y: cy))
        p.move(to: CGPoint(x: cx + gapRadius, y: cy))
        p.addLine(to: CGPoint(x: cx + gapRadius + lineLength, y: cy))
        return p
    }
}

// MARK: - FullscreenTrackingView

private final class FullscreenTrackingView: NSView {

    /// Callback позиции — primary source движения мыши на том экране,
    /// где стоит FullscreenCursorWindow. Global monitor используется
    /// только для других экранов и НЕ дублирует этот callback.
    var onMouseMoved: ((NSPoint) -> Void)?

    private lazy var transparentCursor: NSCursor = {
        let img = NSImage(size: NSSize(width: 1, height: 1))
        img.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: img.size).fill()
        img.unlockFocus()
        return NSCursor(image: img, hotSpot: .zero)
    }()

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        transparentCursor.set()
        guard let win = window else { return }
        let pos = NSPoint(
            x: event.locationInWindow.x + win.frame.minX,
            y: event.locationInWindow.y + win.frame.minY
        )
        onMouseMoved?(pos)
    }

    override func mouseEntered(with event: NSEvent) {
        transparentCursor.set()
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
    private var crosshairPanel: NSPanel?
    private var currentColor: NSColor? = nil
    private let overlaySize = CGSize(width: 22, height: 22)

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
            object: nil,
            queue: .main
        ) { _ in
            if let t = token {
                NotificationCenter.default.removeObserver(t)
                token = nil
            }
            // Два runloop-цикла: macOS завершает restore курсора асинхронно
            DispatchQueue.main.async {
                DispatchQueue.main.async {
                    CursorOverlay.applyTransparentCursor()
                }
            }
        }
    }

    static func applyTransparentCursor() {
        let img = NSImage(size: NSSize(width: 1, height: 1))
        img.lockFocus()
        NSColor.clear.set()
        NSRect(origin: .zero, size: img.size).fill()
        img.unlockFocus()
        NSCursor(image: img, hotSpot: .zero).set()
    }

    func show() {
        let cursorPos = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(cursorPos) })
                     ?? NSScreen.main ?? NSScreen.screens[0]

        ensureFullscreenWindow(on: screen)
        ensureCrosshairPanel()
        installGlobalMouseMonitor()
        guard let fw = fullscreenWindow, let cp = crosshairPanel else { return }

        cp.setFrame(frameForCursor(cursorPos), display: false)
        refreshCrosshair()

        fw.orderFrontRegardless()
        fw.makeKey()
        cp.orderFrontRegardless()
        // Прозрачный курсор установится при первом mouseMoved
    }

    func move(to position: NSPoint) {
        guard let cp = crosshairPanel, cp.isVisible else { return }
        cp.setFrame(frameForCursor(position), display: false)
    }

    func updateColor(_ color: NSColor?) {
        currentColor = color
        refreshCrosshair()
    }

    func hide() {
        crosshairPanel?.orderOut(nil)
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
        // Только .mouseMoved — двигаем crosshair на экранах без FullscreenTrackingView.
        // НЕ вызываем onMouseMoved: это дублировало бы TrackingView на primary screen.
        // НЕ слушаем .leftMouseDragged: этим занимается ColorSampler.mouseMonitor.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .mouseMoved
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

    private func frameForCursor(_ cursor: NSPoint) -> NSRect {
        NSRect(x: cursor.x - overlaySize.width / 2,
               y: cursor.y - overlaySize.height / 2,
               width: overlaySize.width, height: overlaySize.height)
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

    private func ensureCrosshairPanel() {
        guard crosshairPanel == nil else { return }
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: overlaySize.width, height: overlaySize.height),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered, defer: false
        )
        p.isFloatingPanel    = true
        p.level              = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.cursorWindow)) - 1)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        p.isOpaque           = false
        p.backgroundColor    = .clear
        p.hasShadow          = false
        p.hidesOnDeactivate  = false
        p.ignoresMouseEvents = true
        p.appearance         = NSAppearance(named: .darkAqua)
        crosshairPanel = p
    }

    private func refreshCrosshair() {
        guard let panel = crosshairPanel else { return }
        let view = CursorOverlayView(color: currentColor)
        if let hosting = panel.contentView as? NSHostingView<CursorOverlayView> {
            hosting.rootView = view
        } else {
            panel.contentView = NSHostingView(rootView: view)
        }
    }
}
