import AppKit
import CoreGraphics

final class NotchHoverController {
    private let panel: NotchPanelController

    private var globalDownMonitor: Any?
    private var localDownMonitor: Any?

    private let triggerHeight: CGFloat = 34
    private let fallbackTriggerWidth: CGFloat = 186

    init(panel: NotchPanelController) {
        self.panel = panel
    }

    func start() {
        stop()

        // GLOBAL: открыть/закрыть (когда приложение НЕ активно)
        globalDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            guard let self else { return }
            let mouse = NSEvent.mouseLocation
            guard let screen = self.screenForPoint(mouse) else { return }

            let trigger = self.triggerRect(on: screen)
            guard trigger.contains(mouse) else { return }

            let hasNotch = screen.notchGapWidth > 0
            if hasNotch {
                self.panel.toggleAnimated(on: screen)
            } else {
                // на внешнем мониторе: trigger только открывает
                if !self.panel.isVisible {
                    self.panel.showAnimated(on: screen)
                }
            }
        }

        // LOCAL: когда приложение активно (важно: global monitor может не приходить)
        localDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            let mouse = NSEvent.mouseLocation
            guard let screen = self.screenForPoint(mouse) else { return event }

            let hasNotch = screen.notchGapWidth > 0
            let trigger = self.triggerRect(on: screen)

            // ✅ закрытие/открытие по triggerRect на notch, когда приложение активно
            if hasNotch && trigger.contains(mouse) {
                self.panel.toggleAnimated(on: screen)
                return event
            }

            if self.panel.isVisible {
                // ✅ на внешнем мониторе закрытие только по X:
                if !hasNotch { return event }

                // ✅ на notch-экране можно закрывать кликом вне панели
                if !self.panel.isPointInsidePanel(mouse) {
                    self.panel.hideAnimated()
                }
                return event
            }

            // панель скрыта → можно открыть по trigger
            if trigger.contains(mouse) {
                self.panel.showAnimated(on: screen)
            }

            return event
        }
    }

    func stop() {
        if let globalDownMonitor {
            NSEvent.removeMonitor(globalDownMonitor)
            self.globalDownMonitor = nil
        }
        if let localDownMonitor {
            NSEvent.removeMonitor(localDownMonitor)
            self.localDownMonitor = nil
        }
    }

    private func screenForPoint(_ p: NSPoint) -> NSScreen? {
        NSScreen.screens.first(where: { $0.frame.contains(p) }) ?? NSScreen.main
    }

    /// triggerRect всегда в центре Menu Bar (верх экрана).
    private func triggerRect(on screen: NSScreen) -> CGRect {
        let sf = screen.frame
        let w = screen.notchGapWidth
        let triggerWidth = (w > 0) ? w : fallbackTriggerWidth

        let x = sf.midX - triggerWidth / 2
        let y = sf.maxY - triggerHeight
        return CGRect(x: x, y: y, width: triggerWidth, height: triggerHeight)
    }
}

private extension NSScreen {
    var notchGapWidth: CGFloat {
        guard #available(macOS 12.0, *),
              let left = auxiliaryTopLeftArea,
              let right = auxiliaryTopRightArea else { return 0 }
        return max(0, frame.width - left.width - right.width)
    }
}
