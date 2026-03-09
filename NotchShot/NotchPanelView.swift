import SwiftUI
import AppKit
import Combine

enum CaptureMode: CaseIterable, Equatable {
    case selection
    case window
    case screen

    var title: String {
        switch self {
        case .selection: return "Selection"
        case .window: return "Window"
        case .screen: return "Entire Screen"
        }
    }

    var icon: String {
        switch self {
        case .selection: return "rectangle.dashed"
        case .window: return "macwindow"
        case .screen: return "menubar.dock.rectangle"
        }
    }
}

enum CaptureDelay: CaseIterable, Equatable {
    case off
    case s3
    case s5
    case s10

    var seconds: Int {
        switch self {
        case .off: return 0
        case .s3: return 3
        case .s5: return 5
        case .s10: return 10
        }
    }

    var title: String {
        switch self {
        case .off: return "No Delay"
        case .s3: return "3 Seconds"
        case .s5: return "5 Seconds"
        case .s10: return "10 Seconds"
        }
    }

    var shortLabel: String? {
        switch self {
        case .off: return nil
        case .s3: return "3"
        case .s5: return "5"
        case .s10: return "10"
        }
    }
}

final class NotchPanelModel: ObservableObject {
    @Published var mode: CaptureMode = .selection
    @Published var delay: CaptureDelay = .off
}

struct NotchPanelView: View {
    let metrics: NotchMetrics

    @ObservedObject var interaction: NotchPanelInteractionState
    @ObservedObject var model: NotchPanelModel

    let onClose: () -> Void
    let onCapture: (_ mode: CaptureMode, _ delay: CaptureDelay) -> Void
    let onToggleTray: () -> Void
    let onPickColor: () -> Void
    let onModeDelayChanged: () -> Void

    var body: some View {
        Group {
            if metrics.hasNotch {
                notchLayout
            } else {
                noNotchLayout
            }
        }
        .frame(height: metrics.panelHeight)
        .allowsHitTesting(interaction.isEnabled)
        .animation(nil, value: interaction.isEnabled)
        .onChange(of: model.delay) { _, _ in onModeDelayChanged() }
        .onChange(of: model.mode) { _, _ in onModeDelayChanged() }
    }

    private var notchLayout: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let shoulders = max(0, (totalWidth - metrics.notchGap) / 2)

            ZStack {
                NotchShape()
                    .fill(Color.black)
                    .compositingGroup()
                    .offset(y: -metrics.pixel)

                HStack(spacing: 0) {
                    HStack(spacing: metrics.gap) {
                        closeCell
                        modeMenuCell
                        timerMenuCell
                    }
                    .padding(.leading, metrics.edgeSafe)
                    .padding(.trailing, metrics.leftMinToNotch)
                    .frame(width: shoulders, alignment: .leading)

                    Color.clear.frame(width: metrics.notchGap)

                    HStack(spacing: metrics.gap) {
                        trayButtonCell
                        moreCell
                        captureButton
                    }
                    .padding(.leading, metrics.rightMinFromNotch)
                    .padding(.trailing, metrics.edgeSafe)
                    .frame(width: shoulders, alignment: .trailing)
                }
                .frame(height: metrics.panelHeight)
                .opacity(contentOpacity)
                .animation(contentFade, value: interaction.contentVisibility)
            }
        }
    }

    private var noNotchLayout: some View {
        ZStack {
            RoundedRectangle(cornerRadius: metrics.panelRadius, style: .continuous)
                .fill(Color.black)
                .compositingGroup()
                .scaleEffect(panelScale)
                .animation(panelSpring, value: interaction.contentVisibility)

            HStack(spacing: metrics.gap) {
                closeCell
                modeMenuCell
                timerMenuCell
                trayButtonCell
                moreCell
                captureButton
            }
            .padding(.horizontal, metrics.outerSideInset)
            .frame(height: metrics.panelHeight)
            .opacity(contentOpacity)
            .animation(contentFade, value: interaction.contentVisibility)
        }
        .animation(nil, value: model.delay)
        .animation(nil, value: model.mode)
    }

    private var closeCell: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: metrics.iconSize, height: metrics.iconSize)
        }
        .buttonStyle(.plain)
        .frame(width: metrics.cellWidth, height: metrics.iconSize)
        .contentShape(Rectangle())
    }

    private var modeMenuCell: some View {
        Menu {
            Button {
                model.mode = .selection
            } label: {
                Label("Selection", systemImage: CaptureMode.selection.icon)
            }

            Button {
                model.mode = .window
            } label: {
                Label("Window", systemImage: CaptureMode.window.icon)
            }

            Button {
                model.mode = .screen
            } label: {
                Label("Entire Screen", systemImage: CaptureMode.screen.icon)
            }

            Divider()

            Button {
                onPickColor()
            } label: {
                Label("Pick Color", systemImage: "eyedropper")
            }
        } label: {
            Image(systemName: model.mode.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: metrics.iconSize, height: metrics.iconSize)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: metrics.cellWidth, height: metrics.iconSize)
    }

    private var timerMenuCell: some View {
        let digitCount = timerDigitCount
        let digitsWidth = timerDigitsWidth(for: digitCount)
        let hasValue = digitCount > 0

        return Menu {
            ForEach(CaptureDelay.allCases, id: \.self) { delay in
                Button(delay.title) { model.delay = delay }
            }
        } label: {
            HStack(spacing: metrics.timerIconToValueGap) {
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: metrics.iconSize, height: metrics.iconSize)

                Text(model.delay.shortLabel ?? "")
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: digitsWidth, height: 12, alignment: .leading)
                    .opacity(hasValue ? 1 : 0)
                    .transaction { $0.animation = nil }
            }
            .padding(.trailing, hasValue ? metrics.timerTrailingInsetWithValue : 0)
            .frame(width: timerCellWidth(digitsWidth: digitsWidth, hasValue: hasValue), alignment: .leading)
            .contentShape(Rectangle())
            .transaction { $0.animation = nil }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(height: metrics.iconSize)
        .animation(nil, value: model.delay)
    }

    private var trayButtonCell: some View {
        Button(action: onToggleTray) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: metrics.iconSize, height: metrics.iconSize)
        }
        .buttonStyle(.plain)
        .frame(width: metrics.cellWidth, height: metrics.iconSize)
        .contentShape(Rectangle())
    }

    private var moreCell: some View {
        Menu {
            Button("Settings") {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
            Divider()
            Button("Quit NotchShot") {
                NSApp.terminate(nil)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: metrics.iconSize, height: metrics.iconSize)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: metrics.cellWidth, height: metrics.iconSize)
    }

    private var captureButton: some View {
        Button { onCapture(model.mode, model.delay) } label: {
            Text("Capture")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .frame(width: metrics.captureButtonWidth, height: metrics.buttonHeight)
                .background(
                    RoundedRectangle(cornerRadius: metrics.buttonRadius, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func timerDigitsWidth(for digitCount: Int) -> CGFloat {
        switch digitCount {
        case 0: return 0
        case 1: return 8
        default: return metrics.timerValueWidth
        }
    }

    private var timerDigitCount: Int {
        guard let label = model.delay.shortLabel else { return 0 }
        return label.count
    }

    private func timerCellWidth(digitsWidth: CGFloat, hasValue: Bool) -> CGFloat {
        guard hasValue else { return metrics.cellWidth }
        return metrics.iconSize + metrics.timerIconToValueGap + digitsWidth + metrics.timerTrailingInsetWithValue
    }

    private var contentOpacity: Double {
        let t = interaction.contentVisibility
        if t <= 0 { return 0.0 }
        if t >= 1 { return 1.0 }
        return max(0.0, (t - 0.15) / 0.85)
    }

    private var panelScale: CGFloat {
        let t = interaction.contentVisibility
        return CGFloat(0.97 + 0.03 * t)
    }

    private var panelSpring: Animation {
        .spring(response: 0.28, dampingFraction: 0.86, blendDuration: 0.0)
    }

    private var contentFade: Animation {
        .easeOut(duration: 0.16)
    }
}
