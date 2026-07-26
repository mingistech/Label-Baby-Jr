#if os(macOS)
import AppKit

enum LabelDocumentActions {
    @MainActor
    static func createNewLabel() {
        NSDocumentController.shared.newDocument(nil)
    }

    @MainActor
    static func openLabel(at url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
    }
}
#endif
