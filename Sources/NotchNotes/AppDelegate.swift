import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = NotchPanelController()
        panelController?.showDocked()
        NSApp.mainMenu = nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.flush()
    }
}
