import SwiftUI

struct HotkeySettingsView: View {
    @AppStorage(AppSettings.Keys.hotkeyPanelEnabled)      private var panelEnabled      = true
    @AppStorage(AppSettings.Keys.hotkeySelectionEnabled)  private var selectionEnabled  = true
    @AppStorage(AppSettings.Keys.hotkeyFullscreenEnabled) private var fullscreenEnabled = true
    @AppStorage(AppSettings.Keys.hotkeyWindowEnabled)     private var windowEnabled     = true
    @AppStorage(AppSettings.Keys.hotkeyColorEnabled)      private var colorEnabled      = true
    @AppStorage(AppSettings.Keys.hotkeyHUDFormatEnabled)  private var hudFormatEnabled  = true

    var body: some View {
        Form {
            Section {
                HotkeyRow(action: "Toggle Panel",         combo: "⌃⌥⌘N", isEnabled: $panelEnabled)
                HotkeyRow(action: "Selection Screenshot", combo: "⌃⌥⌘R", isEnabled: $selectionEnabled)
                HotkeyRow(action: "Fullscreen Screenshot",combo: "⌃⌥⌘B", isEnabled: $fullscreenEnabled)
                HotkeyRow(action: "Window Screenshot",    combo: "⌃⌥⌘G", isEnabled: $windowEnabled)
                HotkeyRow(action: "Pick Color",           combo: "⌃⌥⌘C", isEnabled: $colorEnabled)
            }
            Section("Color HUD") {
                HotkeyRow(action: "Cycle Color Format",   combo: "F",     isEnabled: $hudFormatEnabled)
            }
            Section {
                HotkeyInfoRow(action: "Move 1 pt",   combos: ["↑", "↓", "←", "→"])
                HotkeyInfoRow(action: "Move 10 pt",  combos: ["⇧↑", "⇧↓", "⇧←", "⇧→"])
                HotkeyInfoRow(action: "Move 50 pt",  combos: ["⇧⌥↑", "⇧⌥↓", "⇧⌥←", "⇧⌥→"])
            } header: {
                Text("Color Picker Movement")
            } footer: {
                Text("Arrow keys nudge the cursor while the color picker is active.")
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

// MARK: - HotkeyInfoRow

/// Display-only row for hardcoded shortcuts that cannot be toggled.
private struct HotkeyInfoRow: View {
    let action: String
    let combos: [String]

    var body: some View {
        LabeledContent(action) {
            HStack(spacing: 6) {
                ForEach(combos, id: \.self) { combo in
                    Text(combo)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(nsColor: .separatorColor))
                                )
                        )
                }
            }
        }
    }
}

// MARK: - HotkeyRow

private struct HotkeyRow: View {
    let action: String
    let combo: String
    @Binding var isEnabled: Bool

    var body: some View {
        LabeledContent(action) {
            HStack(spacing: 12) {
                Text(combo)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(isEnabled ? .primary : .tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(nsColor: .separatorColor))
                            )
                    )
                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        }
    }
}
