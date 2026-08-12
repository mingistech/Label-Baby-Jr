#if os(macOS)
import AppKit

final class LabelBabyJrAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.shared.applyAppearance()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Covers Quit from the menu / ⌘Q when the window close path didn't run first.
        LabelWorkspace.shared.confirmCloseIfNeeded() ? .terminateNow : .terminateCancel
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        DispatchQueue.main.async {
            LabelWorkspace.shared.openLabel(at: url)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // Ensure the single editor window comes back when the dock icon is clicked.
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
#endif
