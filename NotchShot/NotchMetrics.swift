import AppKit

// MARK: - NotchMetrics

/// Геометрические метрики панели, вычисленные из конкретного NSScreen.
/// Используются в NotchPanelController, NotchPanelView и NotchTrayView.
struct NotchMetrics {

    // MARK: Screen

    /// Масштаб экрана (backingScaleFactor).
    let scale: CGFloat

    // MARK: Notch

    /// Есть ли физическая вырезка (notch) на экране.
    let hasNotch: Bool

    /// Ширина области под нотч (notchGapWidth у экрана).
    let notchGap: CGFloat

    // MARK: Panel geometry

    /// Высота панели.
    let panelHeight: CGFloat

    /// Угловой радиус панели (только для no-notch).
    let panelRadius: CGFloat

    /// Отступ панели от внешнего края экрана (no-notch).
    let outerSideInset: CGFloat

    // MARK: Layout constants

    /// Горизонтальный отступ по краям плеч.
    let edgeSafe: CGFloat

    /// Минимальный отступ от левого плеча до нотча.
    let leftMinToNotch: CGFloat

    /// Минимальный отступ от нотча до правого плеча.
    let rightMinFromNotch: CGFloat

    // MARK: Cell sizes

    /// Базовая ширина иконочной ячейки (xmark, photo.stack, ellipsis...).
    let cellWidth: CGFloat

    /// Высота / ширина иконки внутри ячейки.
    let iconSize: CGFloat

    /// Межячеечный промежуток.
    let gap: CGFloat

    // MARK: Timer cell

    /// Промежуток между иконкой таймера и цифрами.
    let timerIconToValueGap: CGFloat

    /// Ширина текста со значением таймера (2 символа).
    let timerValueWidth: CGFloat

    /// Trailing-отступ ячейки таймера, когда цифры видны.
    let timerTrailingInsetWithValue: CGFloat

    // MARK: Capture button

    /// Ширина кнопки «Capture».
    let captureButtonWidth: CGFloat

    // MARK: Button (tray)

    /// Высота кнопок-свотчей в трее.
    let buttonHeight: CGFloat

    /// Угловой радиус кнопок в трее.
    let buttonRadius: CGFloat

    // MARK: Pixel

    /// Один физический пиксель в логических единицах.
    var pixel: CGFloat { 1.0 / max(scale, 1) }

    // MARK: - Factory

    static func from(screen: NSScreen) -> NotchMetrics {
        let scale = screen.backingScaleFactor
        let notchGap = screen.notchGapWidth
        let hasNotch = notchGap > 0

        return NotchMetrics(
            scale: scale,
            hasNotch: hasNotch,
            notchGap: notchGap,
            panelHeight: 34,
            panelRadius: 10,
            outerSideInset: 5,
            edgeSafe: hasNotch ? 20 : 5,
            leftMinToNotch: 36,
            rightMinFromNotch: 12,
            cellWidth: 28,
            iconSize: 24,
            gap: 8,
            timerIconToValueGap: 6,
            timerValueWidth: 16,
            timerTrailingInsetWithValue: 8,
            captureButtonWidth: 71,
            buttonHeight: 24,
            buttonRadius: 8
        )
    }

    static func fallback() -> NotchMetrics {
        from(screen: NSScreen.main ?? NSScreen.screens[0])
    }
}

// MARK: - NSScreen + notchGapWidth

extension NSScreen {
    /// Ширина области под нотч в логических пикселях.
    /// Возвращает 0, если нотча нет.
    var notchGapWidth: CGFloat {
        guard #available(macOS 12.0, *) else { return 0 }
        let safeInsets = safeAreaInsets
        // На MacBook с нотчем top-inset ненулевой.
        guard safeInsets.top > 0 else { return 0 }
        // Ширина нотча — разница между полным фреймом и видимой областью сверху.
        // Apple не предоставляет прямого API, поэтому используем auxiliaryTopLeftArea / auxiliaryTopRightArea.
        if let leftRect = auxiliaryTopLeftArea, let rightRect = auxiliaryTopRightArea {
            let totalWidth = frame.width
            let usable = leftRect.width + rightRect.width
            return max(0, totalWidth - usable)
        }
        return 0
    }
}
