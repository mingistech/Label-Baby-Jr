#if os(macOS)
import AppKit
import Combine

@MainActor
final class LabelEditorController: ObservableObject {
    @Published private(set) var plainText = ""
    @Published var fontSize = LabelTypography.defaultFontSize
    @Published var isBold = false
    @Published var isItalic = false
    @Published var isUnderlined = false
    @Published var alignment: LabelTextAlignment = .center

    fileprivate weak var editor: EditableLabelContainerView?
    private var isSyncingStyleFromEditor = false
    private var isLoadingDocument = false
    private var documentSaveTask: Task<Void, Never>?

    var onDocumentContentChanged: (() -> Void)?

    var canPrint: Bool {
        !plainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func attachEditor(_ editor: EditableLabelContainerView) {
        guard self.editor !== editor else { return }
        self.editor = editor
        syncStyleStateFromEditor()
    }

    func load(from file: LabelBabyJrFile) {
        isLoadingDocument = true
        defer { isLoadingDocument = false }

        editor?.loadContent(from: file)
        syncStyleStateFromEditor()
    }

    func makeFileContent() -> LabelBabyJrFile {
        guard let attributedString = editor?.attributedStringForDocument() else {
            return .empty
        }
        return LabelBabyJrFile.from(attributedString: attributedString)
    }

    func updatePlainText(_ text: String) {
        plainText = text
        notifyDocumentContentChanged()
    }

    func syncStyleStateFromEditor() {
        guard let editor else { return }

        let state = editor.currentStyleState()
        isSyncingStyleFromEditor = true
        defer { isSyncingStyleFromEditor = false }

        if fontSize != state.fontSize { fontSize = state.fontSize }
        if isBold != state.isBold { isBold = state.isBold }
        if isItalic != state.isItalic { isItalic = state.isItalic }
        if isUnderlined != state.isUnderlined { isUnderlined = state.isUnderlined }
        if alignment != state.alignment { alignment = state.alignment }
    }

    func applyFontSize(_ size: CGFloat) {
        guard !isSyncingStyleFromEditor else { return }
        guard abs(fontSize - size) > 0.01 else { return }
        fontSize = size
        editor?.applyFontSize(size)
        syncStyleStateFromEditor()
        notifyDocumentContentChanged()
    }

    func setBold(_ enabled: Bool) {
        guard !isSyncingStyleFromEditor else { return }
        guard isBold != enabled else { return }
        editor?.setBold(enabled)
        syncStyleStateFromEditor()
        notifyDocumentContentChanged()
    }

    func setItalic(_ enabled: Bool) {
        guard !isSyncingStyleFromEditor else { return }
        guard isItalic != enabled else { return }
        editor?.setItalic(enabled)
        syncStyleStateFromEditor()
        notifyDocumentContentChanged()
    }

    func setUnderline(_ enabled: Bool) {
        guard !isSyncingStyleFromEditor else { return }
        guard isUnderlined != enabled else { return }
        editor?.setUnderline(enabled)
        syncStyleStateFromEditor()
        notifyDocumentContentChanged()
    }

    func applyAlignment(_ alignment: LabelTextAlignment) {
        guard !isSyncingStyleFromEditor else { return }
        guard self.alignment != alignment else { return }
        self.alignment = alignment
        editor?.applyAlignment(alignment)
        syncStyleStateFromEditor()
        notifyDocumentContentChanged()
    }

    func attributedStringForPrinting() -> NSAttributedString? {
        editor?.attributedStringForPrinting()
    }

    private func notifyDocumentContentChanged() {
        guard !isLoadingDocument else { return }

        documentSaveTask?.cancel()
        documentSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            onDocumentContentChanged?()
        }
    }
}
#endif
