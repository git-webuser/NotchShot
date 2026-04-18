import Foundation
import SwiftUI

// MARK: - LocaleManager

/// Single source of truth for the app's current display language.
///
/// Reads `preferredLanguage` from UserDefaults and exposes a SwiftUI-observable
/// `locale` property. Inject it at every NSHostingView / NSHostingController root
/// via `.managedLocale()` so language changes take effect instantly — no restart.
///
/// AppKit strings (`String(localized:)` in NSAlert etc.) still use the process
/// locale set by AppDelegate.applicationWillFinishLaunching, which requires a
/// restart to change. Only the SwiftUI view hierarchy is updated in real time here.
@Observable final class LocaleManager {
    static let shared = LocaleManager()

    /// The resolved Locale for the current language preference.
    private(set) var locale: Locale = .autoupdatingCurrent

    private init() {
        refresh()
        // Re-evaluate whenever any UserDefaults key changes (includes @AppStorage writes).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refresh),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
    }

    @objc private func refresh() {
        let pref = UserDefaults.standard.string(forKey: AppSettings.Keys.preferredLanguage) ?? "system"
        let resolved: Locale
        switch pref {
        case "en": resolved = Locale(identifier: "en")
        case "ru": resolved = Locale(identifier: "ru")
        default:   resolved = .autoupdatingCurrent
        }
        // Only write back if changed to avoid spurious SwiftUI re-renders.
        if resolved.identifier != locale.identifier {
            locale = resolved
        }
    }
}

// MARK: - View helper

private struct LocaleAwareWrapper<Content: View>: View {
    let content: Content

    /// Accessing LocaleManager.shared.locale here registers a SwiftUI dependency
    /// on the @Observable property. Any language change triggers a re-render of
    /// this wrapper and propagates the new locale through the content hierarchy.
    var body: some View {
        content.environment(\.locale, LocaleManager.shared.locale)
    }
}

extension View {
    /// Wraps the receiver so its entire subtree uses the locale from LocaleManager.
    /// Call once at each NSHostingView / NSHostingController root — no need to
    /// add it deeper in the hierarchy.
    func managedLocale() -> some View {
        LocaleAwareWrapper(content: self)
    }
}
