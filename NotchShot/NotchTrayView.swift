import SwiftUI
import AppKit
import Foundation
import Combine

struct NotchTrayView: View {
    let hasNotch: Bool
    let notchGap: CGFloat
    let edgeSafe: CGFloat

    @ObservedObject var trayModel: NotchTrayModel
    let onBack: () -> Void

    @State private var scheme: ColorSchemeType = .hex

    var body: some View {
        Group {
            if hasNotch {
                notchLayout
            } else {
                noNotchLayout
            }
        }
        .frame(height: 34)
    }

    private var notchLayout: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let shoulders = max(0, (w - notchGap) / 2)

            ZStack {
                NotchShape().fill(.black)

                HStack(spacing: 0) {
                    leftContent
                        .padding(.leading, edgeSafe)
                        .frame(width: shoulders, alignment: .leading)

                    Color.clear.frame(width: notchGap)

                    rightContent
                        .padding(.trailing, edgeSafe)
                        .frame(width: shoulders, alignment: .trailing)
                }
            }
        }
    }

    private var noNotchLayout: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.black)

            HStack(spacing: 12) {
                leftContent
                Spacer(minLength: 12)
                rightContent
            }
            .padding(.horizontal, edgeSafe)
        }
    }

    private var leftContent: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(ColorSchemeType.allCases, id: \.self) { s in
                    Button(s.title) { scheme = s }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(scheme.title)
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.12))
                )
            }
            .menuIndicator(.hidden)
        }
    }

    private var rightContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(trayModel.colors) { item in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: item.color))
                        .frame(width: 26, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .onTapGesture {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(
                                scheme.convert(item.color),
                                forType: .string
                            )
                        }
                }
            }
        }
        .frame(height: 28)
    }
}

enum ColorSchemeType: CaseIterable, Equatable {
    case hex
    case rgb

    var title: String {
        switch self {
        case .hex: return "HEX"
        case .rgb: return "RGB"
        }
    }

    func convert(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        switch self {
        case .hex:
            return c.hexString
        case .rgb:
            return c.rgbString
        }
    }
}

private extension NSColor {
    var rgbString: String {
        let c = usingColorSpace(.sRGB) ?? self
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return "rgb(\(r), \(g), \(b))"
    }
}

final class NotchTrayModel: ObservableObject {
    @Published private(set) var colors: [TrayColor] = []

    func add(color: NSColor) {
        let c = color.usingColorSpace(.sRGB) ?? color
        let hex = c.hexString

        colors.removeAll { $0.hex == hex }
        colors.insert(TrayColor(color: c, hex: hex), at: 0)

        if colors.count > 8 { colors = Array(colors.prefix(8)) }
    }
}

struct TrayColor: Identifiable, Equatable {
    let id = UUID()
    let color: NSColor
    let hex: String
}

private extension NSColor {
    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? self
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
