import SwiftUI
import AppKit


// MARK: - NotchTrayView

struct NotchTrayView: View {
    let metrics: NotchMetrics
    @ObservedObject var trayModel: NotchTrayModel
    let onBack: () -> Void

    @State private var scheme: ColorSchemeType = .hex

    // Figma viewBox: 536×89. Верхняя часть (нотч) = 34pt, нижняя = 55pt.
    private var scrollPadH:   CGFloat { 16 }
    private var scrollPadTop: CGFloat { 8  }
    private var scrollPadBot: CGFloat { 16 }
    private var cellH:        CGFloat { 36 }
    private var bottomRadius: CGFloat { 16 }

    // Высота нижней части = 89 - 34 = 55pt (из Figma)
    var scrollRowHeight: CGFloat { 55 }
    var trayHeight:      CGFloat { metrics.panelHeight + scrollRowHeight }

    var body: some View {
        Group {
            if metrics.hasNotch {
                notchLayout
            } else {
                noNotchLayout
            }
        }
        .frame(height: trayHeight)
    }

    // MARK: - Notch layout

    private var notchLayout: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let shoulders  = (totalWidth - metrics.notchGap) / 2

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // Верхний ряд — кнопки
                    HStack(spacing: 0) {
                        HStack(spacing: metrics.gap) {
                            backButton
                            schemeMenu
                        }
                        .padding(.leading, metrics.edgeSafe)
                        .frame(width: shoulders, alignment: .leading)

                        Color.clear.frame(width: metrics.notchGap)

                        HStack(spacing: metrics.gap) {
                            trayIconButton
                            moreButton
                        }
                        .padding(.trailing, metrics.edgeSafe)
                        .frame(width: shoulders, alignment: .trailing)
                    }
                    .frame(height: metrics.panelHeight)

                    // Нижний ряд — скролл
                    unifiedScrollView
                        .padding(.horizontal, scrollPadH)
                        .padding(.top, scrollPadTop)
                        .padding(.bottom, scrollPadBot)
                }
            }
        }
    }

    // MARK: - No-notch layout

    private var noNotchLayout: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                HStack(spacing: metrics.gap) {
                    backButton
                    schemeMenu
                    Spacer()
                    trayIconButton
                    moreButton
                }
                .padding(.horizontal, scrollPadH)
                .frame(height: metrics.panelHeight)

                unifiedScrollView
                    .padding(.horizontal, scrollPadH)
                    .padding(.top, scrollPadTop)
                    .padding(.bottom, scrollPadBot)
            }
        }
    }

    // MARK: - Buttons

    private var backButton: some View {
        PanelIconButton(systemName: "chevron.left", size: 14, weight: .semibold, action: onBack)
            .frame(width: metrics.cellWidth, height: metrics.iconSize)
    }

    private var trayIconButton: some View {
        PanelIconButton(
            systemName: "photo.on.rectangle.angled",
            size: 13,
            weight: .regular,
            isActive: true,
            action: {}
        )
        .frame(width: metrics.cellWidth, height: metrics.iconSize)
    }

    private var moreButton: some View {
        PanelMenuButton(
            systemName: "ellipsis.circle",
            size: 14,
            weight: .semibold
        ) {
            Button("Settings") {
                NSApp.sendAction(#selector(AppDelegate.openSettings), to: nil, from: nil)
            }
            Divider()
            Button("Quit NotchShot") { NSApp.terminate(nil) }
        }
        .frame(width: metrics.cellWidth, height: metrics.iconSize)
    }

    // MARK: - Scheme menu

    private var schemeMenuWidth: CGFloat { 68 }

    private var schemeMenu: some View {
        Menu {
            ForEach(ColorSchemeType.allCases, id: \.self) { s in
                Button(s.title) { scheme = s }
            }
        } label: {
            HStack(spacing: 5) {
                Text(scheme.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .frame(height: metrics.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: metrics.buttonRadius, style: .continuous)
                    .fill(Color.white.opacity(0.14))
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: schemeMenuWidth)
    }

    // MARK: - Scroll

    private var unifiedScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(trayModel.items) { item in
                    switch item {
                    case .screenshot(let shot):
                        TrayScreenshotCell(
                            shot: shot,
                            height: cellH,
                            cornerRadius: metrics.buttonRadius,
                            onRemove: { trayModel.remove(id: shot.id) }
                        )
                    case .color(let c):
                        TrayColorCell(
                            item: c,
                            scheme: scheme,
                            height: cellH,
                            cornerRadius: metrics.buttonRadius
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Tray Color Cell

private struct TrayColorCell: View {
    let item: TrayColor
    let scheme: ColorSchemeType
    let height: CGFloat
    let cornerRadius: CGFloat

    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(nsColor: item.color))
            .frame(width: height, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(isHovered ? 0.35 : 0.12), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.88 : (isHovered ? 1.06 : 1.0))
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
            .onHover { isHovered = $0 }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in
                        isPressed = false
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(scheme.convert(item.color), forType: .string)
                    }
            )
    }
}

// MARK: - Tray Screenshot Cell

private struct TrayScreenshotCell: View {
    let shot: TrayScreenshot
    let height: CGFloat
    let cornerRadius: CGFloat
    let onRemove: () -> Void

    @StateObject private var loader = ThumbnailLoader()
    @State private var isHovered = false
    @State private var isPressed = false

    private var width: CGFloat { height * 1.6 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(isHovered ? 0.35 : 0.12), lineWidth: 1)
                )

            if let img = loader.image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: width, height: height)
        .scaleEffect(isPressed ? 0.88 : (isHovered ? 1.04 : 1.0))
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    // Tap: открыть файл (не папку)
                    NSWorkspace.shared.open(shot.url)
                }
        )
        .onDrag {
            NSItemProvider(contentsOf: shot.url) ?? NSItemProvider()
        }
        .contextMenu {
            Button("Open") {
                NSWorkspace.shared.open(shot.url)
            }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([shot.url])
            }
            Button("Copy") {
                NSPasteboard.general.writeImage(at: shot.url)
            }
            Divider()
            Button("Remove from Tray") { onRemove() }
        }
        .task(id: shot.url) {
            loader.load(imageURL: shot.url)
        }
    }
}
