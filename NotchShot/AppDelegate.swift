import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let panel = NotchPanelController()
    private lazy var hover = NotchHoverController(panel: panel)

    func applicationDidFinishLaunching(_ notification: Notification) {
        hover.start()
    }
}
