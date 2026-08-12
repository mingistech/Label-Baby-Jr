#if os(macOS)
import AppKit

enum LabelDocumentActions {
    @MainActor
    static func createNewLabel() {
        LabelWorkspace.shared.newLabel()
    }

    @MainActor
    static func openLabel(at url: URL) {
        LabelWorkspace.shared.openLabel(at: url)
    }
}
#endif
