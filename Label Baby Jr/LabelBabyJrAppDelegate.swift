#if os(macOS)
import AppKit

final class LabelBabyJrAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AppSettings.shared.launchBehavior == .newDocumentEditor else { return }

        DispatchQueue.main.async {
            guard NSDocumentController.shared.documents.isEmpty else { return }
            LabelDocumentActions.createNewLabel()
        }
    }
}
#endif
