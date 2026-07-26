#if os(macOS)
import AppKit
import SwiftUI

struct LabelEditorStyleState {
    var fontSize: CGFloat
    var isBold: Bool
    var isItalic: Bool
    var isUnderlined: Bool
    var alignment: LabelTextAlignment
}

struct EditableLabelView: View {
    let controller: LabelEditorController
    private let previewScale: CGFloat = 1.5

    var body: some View {
        let previewWidth = LabelTypography.widthPoints * previewScale
        let previewHeight = LabelTypography.heightPoints * previewScale

        EditableLabelViewRepresentable(controller: controller, previewScale: previewScale)
            .frame(width: previewWidth, height: previewHeight)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

private struct EditableLabelViewRepresentable: NSViewRepresentable {
    let controller: LabelEditorController
    let previewScale: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeNSView(context: Context) -> EditableLabelContainerView {
        let view = EditableLabelContainerView(previewScale: previewScale)
        view.delegate = context.coordinator
        view.showPlaceholderIfNeeded()
        controller.attachEditor(view)
        return view
    }

    func updateNSView(_ nsView: EditableLabelContainerView, context: Context) {}

    final class Coordinator: NSObject, EditableLabelContainerViewDelegate {
        let controller: LabelEditorController

        init(controller: LabelEditorController) {
            self.controller = controller
        }

        func textDidChange(_ plainText: String) {
            controller.updatePlainText(plainText)
        }

        func selectionDidChange() {
            controller.syncStyleStateFromEditor()
        }

        func preferredStyleState() -> LabelEditorStyleState {
            LabelEditorStyleState(
                fontSize: controller.fontSize,
                isBold: controller.isBold,
                isItalic: controller.isItalic,
                isUnderlined: controller.isUnderlined,
                alignment: controller.alignment
            )
        }
    }
}

protocol EditableLabelContainerViewDelegate: AnyObject {
    func textDidChange(_ plainText: String)
    func selectionDidChange()
    func preferredStyleState() -> LabelEditorStyleState
}

/// Overriding `mouseDown` forces AppKit to use its legacy NSEvent-based
/// click/drag selection handling instead of the newer gesture-recognizer-based
/// selection path, which has a drag-selection regression on this OS.
private final class LegacySelectionTextView: NSTextView {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
    }
}

final class EditableLabelContainerView: NSView {
    weak var delegate: EditableLabelContainerViewDelegate?
    let textView: NSTextView
    let previewScale: CGFloat

    private var isUpdatingFromCode = false
    private var lastVerticalInset: CGFloat = -1
    private var isUpdatingVerticalAlignment = false
    private var showingPlaceholder = false

    init(previewScale: CGFloat = 1.0) {
        self.previewScale = previewScale
        textView = LegacySelectionTextView(frame: .zero)
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: LabelTypography.widthPoints * previewScale,
            height: LabelTypography.heightPoints * previewScale
        ))
        setupTextView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        dirtyRect.fill()
        super.draw(dirtyRect)
    }

    private func setupTextView() {
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.autoresizingMask = [.width, .height]
        textView.delegate = self
        textView.typingAttributes = LabelTypography.attributes(fontSize: scaledFontSize(LabelTypography.defaultFontSize))

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = false
            textContainer.heightTracksTextView = false
            textContainer.lineBreakMode = .byWordWrapping
            textContainer.maximumNumberOfLines = 0
            textContainer.containerSize = NSSize(width: labelContentWidth, height: labelContentHeight)
        }

        addSubview(textView)
        textView.frame = bounds
        refreshVerticalAlignment()
    }

    /// The editor's content area matches its own (scaled) bounds exactly, so
    /// enlarging `previewScale` grows the text and margins together, keeping
    /// them proportional to what will actually be printed.
    private var labelContentWidth: CGFloat { LabelTypography.widthPoints * previewScale }
    private var labelContentHeight: CGFloat { LabelTypography.heightPoints * previewScale }

    private var horizontalInset: CGFloat {
        LabelTypography.horizontalMarginPoints * previewScale
    }

    private func scaledFontSize(_ logicalSize: CGFloat) -> CGFloat {
        logicalSize * previewScale
    }

    private func logicalFontSize(_ displaySize: CGFloat) -> CGFloat {
        displaySize / previewScale
    }

    /// Returns a copy of `source` with all font point sizes divided by the
    /// preview zoom factor, converting on-screen (enlarged) sizes back to the
    /// real print-accurate sizes used for saving and printing.
    private func downscaledForExport(_ source: NSAttributedString) -> NSAttributedString {
        guard previewScale != 1, source.length > 0 else { return source }
        let result = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }
            result.addAttribute(.font, value: NSFontManager.shared.convert(font, toSize: logicalFontSize(font.pointSize)), range: range)
        }
        return result
    }

    /// Returns a copy of `source` with all font point sizes multiplied by the
    /// preview zoom factor, converting real print-accurate sizes (as loaded
    /// from a saved file) into the enlarged sizes used for on-screen display.
    private func upscaledForDisplay(_ source: NSAttributedString) -> NSAttributedString {
        guard previewScale != 1, source.length > 0 else { return source }
        let result = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }
            result.addAttribute(.font, value: NSFontManager.shared.convert(font, toSize: scaledFontSize(font.pointSize)), range: range)
        }
        return result
    }

    private func redrawTextView() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        layoutManager.ensureLayout(for: textContainer)
        textView.setNeedsDisplay(textView.bounds)
        setNeedsDisplay(bounds)
    }

    func showPlaceholderIfNeeded() {
        guard contentPlainText.isEmpty else {
            showingPlaceholder = false
            return
        }

        let style = delegate?.preferredStyleState() ?? LabelEditorStyleState(
            fontSize: LabelTypography.defaultFontSize,
            isBold: false,
            isItalic: false,
            isUnderlined: false,
            alignment: .center
        )

        isUpdatingFromCode = true
        textView.textStorage?.setAttributedString(LabelTypography.placeholderAttributedString(
            alignment: style.alignment.nsAlignment,
            fontSize: scaledFontSize(LabelTypography.defaultFontSize)
        ))
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.typingAttributes = typingAttributes(for: style)
        isUpdatingFromCode = false

        showingPlaceholder = true
        refreshVerticalAlignment()
    }

    func currentStyleState() -> LabelEditorStyleState {
        if showingPlaceholder {
            return delegate?.preferredStyleState() ?? LabelEditorStyleState(
                fontSize: LabelTypography.defaultFontSize,
                isBold: false,
                isItalic: false,
                isUnderlined: false,
                alignment: .center
            )
        }

        let attributes = attributesAtInsertionPoint()
        let font = (attributes[.font] as? NSFont) ?? LabelTypography.font(size: scaledFontSize(LabelTypography.defaultFontSize), bold: false, italic: false)
        let traits = NSFontManager.shared.traits(of: font)
        let underline = (attributes[.underlineStyle] as? Int) == NSUnderlineStyle.single.rawValue
        let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle

        return LabelEditorStyleState(
            fontSize: logicalFontSize(font.pointSize),
            isBold: traits.contains(.boldFontMask),
            isItalic: traits.contains(.italicFontMask),
            isUnderlined: underline,
            alignment: LabelTextAlignment(nsAlignment: paragraph?.alignment ?? .center)
        )
    }

    func applyFontSize(_ size: CGFloat) {
        mutateText(in: safeSelectedRange()) { attributes in
            let font = (attributes[.font] as? NSFont) ?? LabelTypography.font(size: LabelTypography.defaultFontSize, bold: false, italic: false)
            attributes[.font] = NSFontManager.shared.convert(font, toSize: scaledFontSize(size))
        }
    }

    func setBold(_ enabled: Bool) {
        mutateFontTrait(.boldFontMask, enabled: enabled)
    }

    func setItalic(_ enabled: Bool) {
        mutateFontTrait(.italicFontMask, enabled: enabled)
    }

    func setUnderline(_ enabled: Bool) {
        mutateText(in: safeSelectedRange()) { attributes in
            if enabled {
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            } else {
                attributes.removeValue(forKey: .underlineStyle)
            }
        }
    }

    func applyAlignment(_ alignment: LabelTextAlignment) {
        guard let textStorage = textView.textStorage else { return }
        clearPlaceholderIfNeeded()
        guard textStorage.length > 0 else {
            var typingAttributes = textView.typingAttributes
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = alignment.nsAlignment
            paragraphStyle.lineBreakMode = .byWordWrapping
            typingAttributes[.paragraphStyle] = paragraphStyle
            textView.typingAttributes = typingAttributes
            return
        }

        applyAlignmentToAllText(alignment)
        updateTypingAttributesFromSelection()
        refreshVerticalAlignment()
    }

    func attributedStringForPrinting() -> NSAttributedString? {
        guard !showingPlaceholder, let textStorage = textView.textStorage, textStorage.length > 0 else { return nil }

        let copy = NSMutableAttributedString(attributedString: textStorage)
        let fullRange = NSRange(location: 0, length: copy.length)
        copy.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            if let color = value as? NSColor, color.isEqual(NSColor.placeholderTextColor) {
                copy.addAttribute(.foregroundColor, value: NSColor.black, range: range)
            }
        }
        return downscaledForExport(copy)
    }

    func attributedStringForDocument() -> NSAttributedString {
        guard !showingPlaceholder,
              let textStorage = textView.textStorage,
              textStorage.length > 0 else {
            return NSAttributedString(string: "")
        }

        return downscaledForExport(textStorage)
    }

    func loadContent(from file: LabelBabyJrFile) {
        isUpdatingFromCode = true
        defer {
            isUpdatingFromCode = false
            refreshVerticalAlignment()
        }

        let attributedString = upscaledForDisplay(file.makeAttributedString())
        if attributedString.length == 0 {
            textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
            showingPlaceholder = false
            showPlaceholderIfNeeded()
            delegate?.textDidChange("")
            delegate?.selectionDidChange()
            return
        }

        textView.textStorage?.setAttributedString(attributedString)
        showingPlaceholder = false
        textView.setSelectedRange(NSRange(location: attributedString.length, length: 0))
        updateTypingAttributesFromSelection()
        delegate?.textDidChange(textView.string)
        delegate?.selectionDidChange()
    }

    private var contentPlainText: String {
        showingPlaceholder ? "" : textView.string
    }

    private func safeSelectedRange() -> NSRange {
        let storageLength = textView.textStorage?.length ?? 0
        guard storageLength > 0 else { return NSRange(location: 0, length: 0) }

        var selection = textView.selectedRange()
        guard selection.location != NSNotFound else { return NSRange(location: 0, length: 0) }

        selection.location = max(0, min(selection.location, storageLength))
        selection.length = max(0, min(selection.length, storageLength - selection.location))
        return selection
    }

    private func attributesAtInsertionPoint() -> [NSAttributedString.Key: Any] {
        guard let textStorage = textView.textStorage, textStorage.length > 0 else {
            return textView.typingAttributes
        }

        let selection = safeSelectedRange()

        if selection.length > 0 {
            let location = min(selection.location, textStorage.length - 1)
            return textStorage.attributes(at: location, effectiveRange: nil)
        }

        if selection.location >= textStorage.length {
            return textView.typingAttributes
        }

        return textStorage.attributes(at: selection.location, effectiveRange: nil)
    }

    private func mutateFontTrait(_ trait: NSFontTraitMask, enabled: Bool) {
        mutateText(in: safeSelectedRange()) { attributes in
            let font = (attributes[.font] as? NSFont) ?? LabelTypography.font(size: scaledFontSize(LabelTypography.defaultFontSize), bold: false, italic: false)
            let manager = NSFontManager.shared
            attributes[.font] = enabled
                ? manager.convert(font, toHaveTrait: trait)
                : manager.convert(font, toNotHaveTrait: trait)
        }
    }

    private func mutateText(
        in range: NSRange,
        updateAttributes: (inout [NSAttributedString.Key: Any]) -> Void
    ) {
        guard let textStorage = textView.textStorage else { return }
        clearPlaceholderIfNeeded()

        isUpdatingFromCode = true
        textStorage.beginEditing()
        defer {
            textStorage.endEditing()
            isUpdatingFromCode = false
            updateTypingAttributesFromSelection()
            refreshVerticalAlignment()
            redrawTextView()
        }

        if range.length == 0 {
            var attributes = textView.typingAttributes
            updateAttributes(&attributes)
            textView.typingAttributes = attributes
            return
        }

        guard range.location < textStorage.length, NSMaxRange(range) <= textStorage.length else { return }

        textStorage.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
            var mutableAttributes = attributes
            updateAttributes(&mutableAttributes)
            textStorage.setAttributes(mutableAttributes, range: subrange)
        }
    }

    private func updateTypingAttributesFromSelection() {
        textView.typingAttributes = attributesAtInsertionPoint()
    }

    private func clearPlaceholderIfNeeded() {
        guard showingPlaceholder else { return }

        let style = delegate?.preferredStyleState() ?? LabelEditorStyleState(
            fontSize: LabelTypography.defaultFontSize,
            isBold: false,
            isItalic: false,
            isUnderlined: false,
            alignment: .center
        )

        isUpdatingFromCode = true
        textView.textStorage?.setAttributedString(NSAttributedString(string: ""))
        textView.typingAttributes = typingAttributes(for: style)
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        isUpdatingFromCode = false
        showingPlaceholder = false
    }

    private func typingAttributes(for style: LabelEditorStyleState) -> [NSAttributedString.Key: Any] {
        LabelTypography.attributes(
            fontSize: scaledFontSize(style.fontSize),
            bold: style.isBold,
            italic: style.isItalic,
            underlined: style.isUnderlined,
            alignment: style.alignment.nsAlignment
        )
    }

    private func applyAlignmentToAllText(_ alignment: LabelTextAlignment) {
        guard let textStorage = textView.textStorage, textStorage.length > 0 else { return }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment.nsAlignment
        paragraphStyle.lineBreakMode = .byWordWrapping

        isUpdatingFromCode = true
        textStorage.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: textStorage.length)
        )
        isUpdatingFromCode = false
    }

    private func refreshVerticalAlignment() {
        guard !isUpdatingVerticalAlignment,
              bounds.height > 0,
              let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager else { return }

        isUpdatingVerticalAlignment = true
        defer { isUpdatingVerticalAlignment = false }

        let savedSelection = textView.selectedRange()

        textContainer.containerSize = NSSize(width: labelContentWidth, height: labelContentHeight)
        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        let usedHeight: CGFloat
        if glyphRange.length > 0 {
            usedHeight = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer).height
        } else {
            usedHeight = LabelTypography.font(size: scaledFontSize(LabelTypography.defaultFontSize), bold: false, italic: false).boundingRectForFont.height
        }

        let insetX = horizontalInset
        let insetY = max(0, (bounds.height - usedHeight) / 2)
        let newInset = NSSize(width: insetX, height: insetY)

        if abs(insetY - lastVerticalInset) > 0.25 || textView.textContainerInset != newInset {
            lastVerticalInset = insetY
            isUpdatingFromCode = true
            textView.textContainerInset = newInset
            if savedSelection.location != NSNotFound {
                textView.setSelectedRange(savedSelection)
            }
            isUpdatingFromCode = false
            redrawTextView()
        }
    }

    private var lastLayoutBounds: NSSize = .zero

    override func layout() {
        super.layout()
        textView.frame = bounds

        guard bounds.height > 0, bounds.size != lastLayoutBounds else { return }
        lastLayoutBounds = bounds.size
        refreshVerticalAlignment()
    }
}

extension EditableLabelContainerView: NSTextViewDelegate {
    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        guard showingPlaceholder else { return true }
        clearPlaceholderIfNeeded()
        return true
    }

    func textDidBeginEditing(_ notification: Notification) {
        clearPlaceholderIfNeeded()
    }

    func textDidChange(_ notification: Notification) {
        guard !isUpdatingFromCode else { return }

        if textView.string == LabelTypography.placeholderText {
            showingPlaceholder = true
            delegate?.textDidChange("")
            return
        }

        if textView.string.isEmpty {
            showPlaceholderIfNeeded()
            delegate?.textDidChange("")
            return
        }

        showingPlaceholder = false
        delegate?.textDidChange(textView.string)
        refreshVerticalAlignment()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard !isUpdatingFromCode else { return }
        delegate?.selectionDidChange()
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if showingPlaceholder || contentPlainText.isEmpty {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                return true
            }
        }
        return false
    }
}
#endif
