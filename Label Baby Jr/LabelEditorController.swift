#if os(macOS)
import AppKit
import Combine

@MainActor
final class LabelEditorController: ObservableObject {
    @Published private(set) var plainText = ""

    /// The largest size the label's text is allowed to grow to. The size actually
    /// drawn is chosen by the auto-fit sizer and reported back as `fittedFontSize`.
    @Published private(set) var maximumFontSize = LabelTypography.defaultMaximumFontSize
    @Published private(set) var fittedFontSize = LabelTypography.defaultMaximumFontSize
    @Published private(set) var isTextOverflowing = false

    /// False once the user has sized text by hand, which hands sizing over to them
    /// until they switch auto-sizing back on.
    @Published private(set) var isAutoSizeEnabled = true

    /// Size of the text at the insertion point, or of the selection's first run.
    @Published private(set) var selectionFontSize = LabelTypography.defaultMaximumFontSize

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

        // Set before loading so a hand-sized label isn't re-fitted on open.
        isAutoSizeEnabled = file.autoSize
        maximumFontSize = Self.clampedFontSize(CGFloat(file.maxFontSize))

        editor?.loadContent(from: file)
        syncStyleStateFromEditor()
    }

    func makeFileContent() -> LabelBabyJrFile {
        guard let attributedString = editor?.attributedStringForDocument() else {
            return .empty
        }

        var file = LabelBabyJrFile.from(attributedString: attributedString)
        file.autoSize = isAutoSizeEnabled
        file.maxFontSize = Double(maximumFontSize)
        return file
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

        if isBold != state.isBold { isBold = state.isBold }
        if isItalic != state.isItalic { isItalic = state.isItalic }
        if isUnderlined != state.isUnderlined { isUnderlined = state.isUnderlined }
        if alignment != state.alignment { alignment = state.alignment }
        if abs(selectionFontSize - state.fontSize) > 0.01 { selectionFontSize = state.fontSize }
    }

    func setMaximumFontSize(_ size: CGFloat) {
        let clamped = Self.clampedFontSize(size)
        guard abs(maximumFontSize - clamped) > 0.01 else { return }
        maximumFontSize = clamped
        editor?.applyAutoFit()
        notifyDocumentContentChanged()
    }

    /// Sizes the selected text by hand, which switches auto-sizing off: the user's
    /// size would otherwise be overwritten by the next re-fit.
    func applyFontSize(_ size: CGFloat) {
        guard !isSyncingStyleFromEditor else { return }

        let clamped = Self.clampedFontSize(size)
        isAutoSizeEnabled = false
        editor?.applyFontSize(clamped)
        syncStyleStateFromEditor()
        notifyDocumentContentChanged()
    }

    func setAutoSizeEnabled(_ enabled: Bool) {
        guard isAutoSizeEnabled != enabled else { return }
        isAutoSizeEnabled = enabled
        // Turning it back on re-fits the label; turning it off keeps the sizes
        // currently on screen as the user's starting point.
        editor?.applyAutoFit()
        syncStyleStateFromEditor()
        notifyDocumentContentChanged()
    }

    /// Sizes are whole points, both the auto-size ceiling and hand-picked sizes.
    private static func clampedFontSize(_ size: CGFloat) -> CGFloat {
        min(max(size.rounded(), LabelTypography.minimumFontSize), LabelTypography.maximumFontSize)
    }

    /// Called by the editor whenever it has re-measured and resized the text.
    func autoFitDidUpdate(fontSize: CGFloat, fitsWithinBounds: Bool) {
        if abs(fittedFontSize - fontSize) > 0.01 { fittedFontSize = fontSize }
        if isTextOverflowing != !fitsWithinBounds { isTextOverflowing = !fitsWithinBounds }
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
