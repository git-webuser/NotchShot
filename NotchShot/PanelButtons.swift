import SwiftUI

// MARK: - PanelIconButton

/// Единая кнопка-иконка для панели с hover и active состояниями.
struct PanelIconButton: View {
    let systemName: String
    let size: CGFloat
    let weight: Font.Weight
    let isActive: Bool
    let action: () -> Void

    @State private var isHovered = false
    @State private var isPressed = false

    init(
        systemName: String,
        size: CGFloat = 14,
        weight: Font.Weight = .semibold,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemName = systemName
        self.size = size
        self.weight = weight
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(foregroundColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(backgroundFill)
                )
        }
        .buttonStyle(PanelButtonStyle(isHovered: $isHovered, isPressed: $isPressed))
        .contentShape(Rectangle())
    }

    private var foregroundColor: Color {
        if isPressed { return .white }
        if isHovered { return .white }
        if isActive  { return .white }
        return .white.opacity(0.8)
    }

    private var backgroundFill: Color {
        if isPressed             { return .white.opacity(0.28) }
        if isActive && isHovered { return .white.opacity(0.32) }
        if isHovered             { return .white.opacity(0.16) }
        if isActive              { return .white.opacity(0.22) }
        return .clear
    }
}

// MARK: - PanelMenuButton

struct PanelMenuButton<MenuContent: View>: View {
    let systemName: String
    let size: CGFloat
    let weight: Font.Weight
    @ViewBuilder let menuContent: () -> MenuContent

    @State private var isHovered  = false
    @State private var isPressed  = false
    @State private var isMenuOpen = false

    var body: some View {
        Menu {
            menuContent()
                .onAppear    { isMenuOpen = true  }
                .onDisappear { isMenuOpen = false }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: size, weight: weight))
                .foregroundStyle(foregroundColor)
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(backgroundFill)
                )
                .contentShape(Rectangle())
                .scaleEffect(isPressed ? 0.88 : 1.0)
                .animation(.spring(response: 0.18, dampingFraction: 0.7), value: isPressed)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .animation(.easeInOut(duration: 0.12), value: isMenuOpen)
    }

    private var foregroundColor: Color {
        if isMenuOpen { return .white }
        if isPressed  { return .white }
        if isHovered  { return .white }
        return .white.opacity(0.8)
    }

    private var backgroundFill: Color {
        if isMenuOpen { return .white.opacity(0.22) }
        if isPressed  { return .white.opacity(0.20) }
        if isHovered  { return .white.opacity(0.10) }
        return .clear
    }
}

// MARK: - PanelButtonStyle

/// Кастомный ButtonStyle — перехватывает hover и press без отмены стандартного поведения кнопки.
struct PanelButtonStyle: ButtonStyle {
    @Binding var isHovered: Bool
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
            .onHover { isHovered = $0 }
            .onChange(of: configuration.isPressed) { _, v in isPressed = v }
    }
}
