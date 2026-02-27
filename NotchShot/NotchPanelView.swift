import SwiftUI

struct NotchPanelView: View {
    let cornerRadius: CGFloat
    let hasNotch: Bool
    let notchGap: CGFloat
    let edgeSafe: CGFloat
    let leftMinToNotch: CGFloat
    let rightMinFromNotch: CGFloat

    @ObservedObject var interaction: NotchPanelInteractionState
    let onClose: () -> Void

    // Figma sizes
    private let height: CGFloat = 34
    private let cellWidth: CGFloat = 28
    private let iconSize: CGFloat = 24
    private let gap: CGFloat = 8
    private let captureButtonSize = CGSize(width: 71, height: 24)

    private let timerTrailingInset: CGFloat = 8
    private let timerIconToValueGap: CGFloat = 6

    @State private var mode: CaptureMode = .selection
    @State private var delay: Delay = .s10

    var body: some View {
        Group {
            if hasNotch {
                notchLayout
            } else {
                noNotchLayout
            }
        }
        .frame(height: height)
        .allowsHitTesting(interaction.isEnabled)
        // не даём SwiftUI "переанимировать" hit-testing сам по себе
        .animation(nil, value: interaction.isEnabled)
    }

    // MARK: - Notch layout (“весы”)

    private var notchLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let shoulders = max(0, (w - notchGap) / 2)

            ZStack {
                NotchShape().fill(.black)

                HStack(spacing: 0) {
                    // LEFT
                    HStack(spacing: gap) { closeCell; modeCell; timerCell }
                        .padding(.leading, edgeSafe)
                        .padding(.trailing, leftMinToNotch)
                        .frame(width: shoulders, alignment: .leading)

                    Color.clear.frame(width: notchGap)

                    // RIGHT
                    HStack(spacing: gap) { photoCell; moreCell; captureButton }
                        .padding(.leading, rightMinFromNotch)
                        .padding(.trailing, edgeSafe)
                        .frame(width: shoulders, alignment: .trailing)
                }
                // ✅ более заметный “system-like” эффект
                .opacity(contentOpacity)
                .blur(radius: contentBlur)
                .scaleEffect(contentScale)
                .frame(height: height)
            }
        }
    }

    // MARK: - No notch layout (таблетка)

    private var noNotchLayout: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.black)

            HStack(spacing: gap) {
                closeCell
                modeCell
                timerCell
                photoCell
                moreCell
                captureButton
            }
            .padding(.horizontal, edgeSafe)
            .opacity(contentOpacity)
            .blur(radius: contentBlur)
            .scaleEffect(contentScale)
            .frame(height: height)
        }
    }

    // MARK: - Cells

    private var closeCell: some View {
        Button(action: onClose) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: iconSize, height: iconSize)
        }
        .buttonStyle(.plain)
        .frame(width: cellWidth, height: iconSize)
        .contentShape(Rectangle())
    }

    private var modeCell: some View {
        Menu {
            Button("Selection") { mode = .selection }
            Button("Window") { mode = .window }
            Button("Entire Screen") { mode = .screen }
            Divider()
            Button("Pick Color") { mode = .color }
        } label: {
            Image(systemName: mode.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: iconSize, height: iconSize)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: cellWidth, height: iconSize)
    }

    private var timerCell: some View {
        Menu {
            Button("No Delay") { delay = .off }
            Button("3 Seconds") { delay = .s3 }
            Button("5 Seconds") { delay = .s5 }
            Button("10 Seconds") { delay = .s10 }
        } label: {
            HStack(spacing: timerIconToValueGap) {
                Image(systemName: "timer")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(width: iconSize, height: iconSize)

                if let label = delay.shortLabel {
                    Text(label)
                        .font(.system(size: 12, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(height: 12)
                }
            }
            .padding(.trailing, timerTrailingInset)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(height: iconSize)
    }

    private var photoCell: some View {
        Button { NSSound.beep() } label: {
            Image(systemName: "photo.stack")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: iconSize, height: iconSize)
        }
        .buttonStyle(.plain)
        .frame(width: cellWidth, height: iconSize)
        .contentShape(Rectangle())
    }

    private var moreCell: some View {
        Menu {
            Button("Settings") {}
            Button("Help") {}
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: iconSize, height: iconSize)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: cellWidth, height: iconSize)
    }

    private var captureButton: some View {
        Button { NSSound.beep() } label: {
            Text(mode == .color ? "Start" : "Capture")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: captureButtonSize.width, height: captureButtonSize.height)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.accentColor)
        )
        .foregroundStyle(.white)
        .contentShape(Rectangle())
    }

    // MARK: - Content animation helpers (делают эффект заметнее)

    private var contentOpacity: Double {
        // Чтобы не было “чуть-чуть”, делаем hold в начале:
        // первые ~15% прогресса почти 0, затем быстро растёт.
        let t = interaction.contentVisibility
        if t <= 0 { return 0.0 }
        if t >= 1 { return 1.0 }
        let held = max(0.0, (t - 0.15) / 0.85)
        return held
    }

    private var contentBlur: CGFloat {
        // Сильнее заметно чем чистый opacity, похоже на системные popover’ы.
        let t = interaction.contentVisibility
        return CGFloat((1.0 - t) * 6.0)
    }

    private var contentScale: CGFloat {
        // Едва заметный “подъезд” контента.
        let t = interaction.contentVisibility
        return CGFloat(0.985 + 0.015 * t)
    }
}

// MARK: - State

private enum CaptureMode {
    case selection, window, screen, color
    var icon: String {
        switch self {
        case .selection: return "rectangle.dashed"
        case .window: return "macwindow"
        case .screen: return "menubar.dock.rectangle"
        case .color: return "eyedropper.halffull"
        }
    }
}

private enum Delay {
    case off, s3, s5, s10
    var shortLabel: String? {
        switch self {
        case .off: return nil
        case .s3: return "3"
        case .s5: return "5"
        case .s10: return "10"
        }
    }
}
