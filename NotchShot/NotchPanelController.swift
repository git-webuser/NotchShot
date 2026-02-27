import AppKit
import SwiftUI
import Combine

/// Управляет интерактивностью и "живостью" SwiftUI-контента внутри панели.
/// Пока идёт анимация — isEnabled = false → .allowsHitTesting(false).
final class NotchPanelInteractionState: ObservableObject {
    @Published var isEnabled: Bool = true

    /// 0...1 — видимость контента внутри панели (не влияет на фон панели).
    /// View сам превращает это в opacity+blur+scale.
    @Published var contentVisibility: Double = 1.0
}

final class NotchPanelController: NSObject {
    private var panel: NSPanel?
    private var currentScreen: NSScreen?

    private let interactionState = NotchPanelInteractionState()

    // Base sizes (Figma)
    private let height: CGFloat = 34
    private let cornerRadius: CGFloat = 10
    private let outerSideInset: CGFloat = 5
    private let earInsetNotch: CGFloat = 15

    // Layout constraints
    private let cellWidth: CGFloat = 28
    private let gap: CGFloat = 8
    private let leftMinToNotch: CGFloat = 36
    private let rightMinFromNotch: CGFloat = 12
    private let captureButtonWidth: CGFloat = 71

    // Timer internals
    private let timerValueWidth: CGFloat = 13
    private let timerIconToValueGap: CGFloat = 6
    private let timerTrailingInset: CGFloat = 8

    // Dynamic screen metrics
    private var hasNotch: Bool = true
    private var notchGap: CGFloat = 186 // fallback
    private var collapsedWidth: CGFloat { notchGap }

    private var edgeSafe: CGFloat {
        outerSideInset + (hasNotch ? earInsetNotch : 0)
    }

    private var expandedWidth: CGFloat {
        // Notch: “весы” (shoulders равные)
        if hasNotch {
            let timerCell = cellWidth + timerIconToValueGap + timerValueWidth + timerTrailingInset

            let leftMin = edgeSafe
                + cellWidth + gap
                + cellWidth + gap
                + timerCell
                + leftMinToNotch

            let rightMin = rightMinFromNotch
                + cellWidth + gap
                + cellWidth + gap
                + captureButtonWidth
                + edgeSafe

            let shoulder = max(leftMin, rightMin)
            return collapsedWidth + 2 * shoulder
        }

        // No-notch: обычная “таблетка” без разделения на левую/правую часть
        let timerCell = cellWidth + timerIconToValueGap + timerValueWidth + timerTrailingInset

        let left = edgeSafe
            + cellWidth + gap
            + cellWidth + gap
            + timerCell

        let right = edgeSafe
            + cellWidth + gap
            + cellWidth + gap
            + captureButtonWidth

        return left + right
    }

    private(set) var isExpanded: Bool = false
    var isVisible: Bool { panel?.isVisible == true }

    // MARK: - Public

    func toggleAnimated(on screen: NSScreen) {
        isVisible ? hideAnimated() : showAnimated(on: screen)
    }

    func showAnimated(on screen: NSScreen) {
        currentScreen = screen
        updateScreenMetrics(for: screen)

        if panel == nil { create() }
        guard let panel else { return }

        // обновим rootView (под hasNotch / notchGap)
        refreshRootViewIfNeeded()

        // ✅ Делает эффект заметнее: контент реально "пустой" в начале,
        // держится так пока панель двигается, затем проявляется.
        interactionState.isEnabled = false
        interactionState.contentVisibility = 0.0

        DispatchQueue.main.async {
            // чуть позже и чуть дольше — так визуально ближе к macOS
            withAnimation(.easeOut(duration: 0.22).delay(0.10)) {
                self.interactionState.contentVisibility = 1.0
            }
        }

        panel.alphaValue = 1
        panel.orderFrontRegardless()

        if hasNotch {
            // NOTCH: коллапс → expand по ширине
            isExpanded = false
            setPanelFrame(panel, width: collapsedWidth, on: screen, animated: false, duration: 0, timing: CAMediaTimingFunction(name: .linear))

            isExpanded = true
            setPanelFrame(
                panel,
                width: clampedWidth(expandedWidth, on: screen),
                on: screen,
                animated: true,
                duration: 0.20,
                timing: CAMediaTimingFunction(name: .easeOut)
            ) { [weak self] in
                self?.interactionState.isEnabled = true
            }
        } else {
            // NO-NOTCH: таблетка фиксированной ширины, анимация только по Y
            isExpanded = true

            let w = clampedWidth(expandedWidth, on: screen)
            let hidden = frameNoNotchHiddenAbove(width: w, on: screen)
            let visible = frameForWidth(w, on: screen)

            panel.setFrame(hidden, display: true)

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.20
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(visible, display: true)
            } completionHandler: { [weak self] in
                self?.interactionState.isEnabled = true
            }
        }
    }

    func showAnimated() {
        guard let screen = NSScreen.main else { return }
        showAnimated(on: screen)
    }

    func hideAnimated() {
        guard let panel, panel.isVisible else { return }

        interactionState.isEnabled = false

        // ✅ Контент исчезает сразу и чуть быстрее, чем геометрия.
        DispatchQueue.main.async {
            withAnimation(.easeIn(duration: 0.16)) {
                self.interactionState.contentVisibility = 0.0
            }
        }

        guard let screen = (currentScreen ?? NSScreen.main ?? NSScreen.screens.first) else {
            panel.orderOut(nil)
            interactionState.isEnabled = true
            return
        }

        if hasNotch {
            isExpanded = false
            setPanelFrame(
                panel,
                width: collapsedWidth,
                on: screen,
                animated: true,
                duration: 0.18,
                timing: CAMediaTimingFunction(name: .easeInEaseOut)
            ) { [weak self, weak panel] in
                panel?.orderOut(nil)
                self?.interactionState.isEnabled = true
            }
        } else {
            isExpanded = false
            let w = clampedWidth(expandedWidth, on: screen)
            let hidden = frameNoNotchHiddenAbove(width: w, on: screen)

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().setFrame(hidden, display: true)
            } completionHandler: { [weak self, weak panel] in
                panel?.orderOut(nil)
                self?.interactionState.isEnabled = true
            }
        }
    }

    func isPointInsidePanel(_ point: NSPoint) -> Bool {
        guard let panel else { return false }
        return panel.frame.contains(point)
    }

    // MARK: - Private

    private func create() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: collapsedWidth, height: height),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false

        panel.appearance = NSAppearance(named: .darkAqua)

        panel.contentView = NSHostingView(rootView: makeRootView())
        self.panel = panel
    }

    private func makeRootView() -> NotchPanelView {
        NotchPanelView(
            cornerRadius: cornerRadius,
            hasNotch: hasNotch,
            notchGap: notchGap,
            edgeSafe: edgeSafe,
            leftMinToNotch: leftMinToNotch,
            rightMinFromNotch: rightMinFromNotch,
            interaction: interactionState,
            onClose: { [weak self] in self?.hideAnimated() }
        )
    }

    private func refreshRootViewIfNeeded() {
        guard let hosting = panel?.contentView as? NSHostingView<NotchPanelView> else { return }
        hosting.rootView = makeRootView()
    }

    private func updateScreenMetrics(for screen: NSScreen) {
        let gap = screen.notchGapWidth
        if gap > 0 {
            hasNotch = true
            notchGap = gap
        } else {
            hasNotch = false
            notchGap = 186
        }
    }

    private func clampedWidth(_ w: CGFloat, on screen: NSScreen) -> CGFloat {
        let maxW = screen.frame.width - 16 // 8pt слева/справа
        return min(max(w, collapsedWidth), maxW)
    }

    private func setPanelFrame(
        _ panel: NSPanel,
        width: CGFloat,
        on screen: NSScreen,
        animated: Bool,
        duration: TimeInterval,
        timing: CAMediaTimingFunction,
        completion: (() -> Void)? = nil
    ) {
        let target = frameForWidth(width, on: screen)

        guard animated else {
            panel.setFrame(target, display: true)
            completion?()
            return
        }

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = timing
            panel.animator().setFrame(target, display: true)
        } completionHandler: {
            completion?()
        }
    }

    private func frameForWidth(_ width: CGFloat, on screen: NSScreen?) -> NSRect {
        guard let screen else { return NSRect(x: 0, y: 0, width: width, height: height) }

        let sf = screen.frame
        let margin: CGFloat = 8

        var x = sf.midX - width / 2
        x = max(sf.minX + margin, min(x, sf.maxX - margin - width))

        let topInsetNoNotch: CGFloat = 5

        let y: CGFloat
        if hasNotch {
            y = sf.maxY - height
        } else {
            y = screen.visibleFrame.maxY - height - topInsetNoNotch
        }

        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func frameNoNotchHiddenAbove(width: CGFloat, on screen: NSScreen?) -> NSRect {
        guard let screen else { return NSRect(x: 0, y: 0, width: width, height: height) }

        let sf = screen.frame
        let margin: CGFloat = 8

        var x = sf.midX - width / 2
        x = max(sf.minX + margin, min(x, sf.maxX - margin - width))

        let y = sf.maxY + 1
        return NSRect(x: x, y: y, width: width, height: height)
    }
}

// MARK: - Notch helpers

private extension NSScreen {
    var notchGapWidth: CGFloat {
        guard #available(macOS 12.0, *),
              let left = auxiliaryTopLeftArea,
              let right = auxiliaryTopRightArea else {
            return 0
        }
        let w = frame.width - left.width - right.width
        return max(0, w)
    }
}
