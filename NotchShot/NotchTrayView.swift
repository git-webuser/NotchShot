import SwiftUI
import AppKit


// MARK: - NotchTrayView

struct NotchTrayView: View {
    let metrics: NotchMetrics
    @ObservedObject var trayModel: NotchTrayModel
    let onBack: () -> Void

    @State private var scheme: ColorSchemeType = .hex

    private let scrollPadH:    CGFloat = 18
    private let cellH:         CGFloat = 32
    private let cellSpacing:   CGFloat = 8
    private let badgeOffset:   CGFloat = 4
    private let padTop:        CGFloat = 3

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

    private var notchLayout: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let shoulders  = (totalWidth - metrics.notchGap) / 2

            ZStack(alignment: .top) {
                VStack(spacing: 0) {
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

                    bottomContent
                        .frame(height: scrollRowHeight)
                }
            }
        }
    }

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

                bottomContent
                    .frame(height: scrollRowHeight)
            }
        }
    }

    @ViewBuilder
    private var bottomContent: some View {
        if trayModel.items.isEmpty {
            emptyState
        } else {
            scrollContent
        }
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
            VStack(alignment: .leading, spacing: 1) {
                Text("Nothing Here Yet")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                Text("Screenshots and colors you capture will appear here.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.25))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    private var scrollContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: cellSpacing) {
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
                            cornerRadius: metrics.buttonRadius,
                            onRemove: { trayModel.remove(id: c.id) }
                        )
                    }
                }
            }
            .padding(.leading, scrollPadH)
            .padding(.trailing, scrollPadH)
            .padding(.top, badgeOffset)
        }
        .padding(.top, padTop - badgeOffset)
    }

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
            action: onBack
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
}

// MARK: - Delete Badge

private struct TrayDeleteBadge: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    Color(red: 0.125, green: 0.125, blue: 0.125), // #202020 — xmark
                    Color(white: 0.914)                            // #E9E9E9 — circle
                )
                .font(.system(size: 16))
                .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .frame(width: 16, height: 16)
    }
}

// MARK: - Tray Color Cell

private struct TrayColorCell: View {
    let item: TrayColor
    let scheme: ColorSchemeType
    let height: CGFloat
    let cornerRadius: CGFloat
    let onRemove: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false
    @State private var isRemoving = false

    var body: some View {
        VStack(spacing: 1) {
            // Swatch scales; badge is inside overlay so it doesn't scale
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(nsColor: item.color))
                .frame(width: height, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(isHovered ? 0.35 : 0.12), lineWidth: 1)
                )
                .scaleEffect(isRemoving ? 0.6 : (isPressed ? 0.88 : (isHovered ? 1.0625 : 1.0)))
                .overlay(alignment: .topTrailing) {
                    TrayDeleteBadge {
                        withAnimation(.easeIn(duration: 0.16)) { isRemoving = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { onRemove() }
                    }
                    .opacity(isHovered ? 1 : 0)
                    .allowsHitTesting(isHovered)
                    .offset(x: 4, y: -4)
                }

            // Label doesn't scale
            Text(scheme.convert(item.color))
                .font(.system(size: 11, weight: .regular, design: .default))
                .textCase(nil)
                .foregroundStyle(.white)
                .fixedSize()
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.65))
                )
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(false)
                .frame(height: 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .padding(.top, -8)
        .padding(.bottom, -16)
        .opacity(isRemoving ? 0 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
        .animation(.easeIn(duration: 0.16), value: isRemoving)
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
    @State private var isRemoving = false

    private var width: CGFloat { height * 1.6 }

    private var displayName: String {
        shot.url.deletingPathExtension().lastPathComponent
    }

    var body: some View {
        VStack(spacing: 1) {
            // Thumbnail scales; badge overlay is applied after scaleEffect so it doesn't scale
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
            .scaleEffect(isRemoving ? 0.6 : (isPressed ? 0.88 : (isHovered ? 1.0625 : 1.0)))
            .overlay(alignment: .topTrailing) {
                TrayDeleteBadge {
                    withAnimation(.easeIn(duration: 0.16)) { isRemoving = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { onRemove() }
                }
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(isHovered)
                .offset(x: 4, y: -4)
            }

            // Label doesn't scale
            Text(displayName)
                .font(.system(size: 11, weight: .regular, design: .default))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.65))
                )
                .frame(maxWidth: width)
                .opacity(isHovered ? 1 : 0)
                .allowsHitTesting(false)
                .frame(height: 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 16)
        .padding(.top, -8)
        .padding(.bottom, -16)
        .opacity(isRemoving ? 0 : 1)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)
        .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
        .animation(.easeIn(duration: 0.16), value: isRemoving)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    NSWorkspace.shared.open(shot.url)
                }
        )
        .onDrag {
            NSItemProvider(contentsOf: shot.url) ?? NSItemProvider()
        }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(shot.url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([shot.url]) }
            Button("Copy") { NSPasteboard.general.writeImage(at: shot.url) }
            Divider()
            Button("Remove from Tray") {
                withAnimation(.easeIn(duration: 0.16)) { isRemoving = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { onRemove() }
            }
        }
        .task(id: shot.url) { loader.load(imageURL: shot.url) }
    }
}
