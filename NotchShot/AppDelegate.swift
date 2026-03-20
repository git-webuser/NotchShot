import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = NotchPanelController()
    private lazy var hover = NotchHoverController(panel: panel)

    func applicationDidFinishLaunching(_ notification: Notification) {
        hover.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Страховка: возвращаем курсор если приложение завершилось во время сэмплинга
        CGDisplayShowCursor(CGMainDisplayID())
    }
    
    @objc func openSettings(_ sender: Any?) {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}
