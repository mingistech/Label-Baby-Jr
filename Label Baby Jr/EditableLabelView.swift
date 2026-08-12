#if os(macOS)
import AppKit
import SwiftUI

struct LabelEditorStyleState {
    /// When read from the editor this is the size at the insertion point; when
    /// supplied *to* the editor it is the ceiling the auto-fit sizer may grow to.
    var fontSize: CGFloat
    var isBold: Bool
    var isItalic: Bool
    var isUnderlined: Bool
    var alignment: LabelTextAlignment
}

struct EditableLabelView: View {
    let controller: LabelEditorController
    private let previewScale: CGFloat = 1.72

    var body: some View {
        LabelStockPreview(previewScale: previewScale, borderColor: Color.accentColor.opacity(0.4)) {
            EditableLabelViewRepresentable(controller: controller, previewScale: previewScale)
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
        view.refreshPlaceholder()
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

        func autoFitDidUpdate(fontSize: CGFloat, fitsWithinBounds: Bool) {
            controller.autoFitDidUpdate(fontSize: fontSize, fitsWithinBounds: fitsWithinBounds)
        }

        func isAutoSizeEnabled() -> Bool {
            controller.isAutoSizeEnabled
        }

        func preferredStyleState() -> LabelEditorStyleState {
            LabelEditorStyleState(
                fontSize: controller.maximumFontSize,
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
    func autoFitDidUpdate(fontSize: CGFloat, fitsWithinBounds: Bool)
    func preferredStyleState() -> LabelEditorStyleState
    func isAutoSizeEnabled() -> Bool
}

/// Overriding `mouseDown` forces AppKit to use its legacy NSEvent-based
/// click/drag selection handling instead of the newer gesture-recognizer-based
/// selection path, which has a drag-selection regression on this OS.
private final class LegacySelectionTextView: NSTextView {
    /// The placeholder is drawn on top of an *empty* text storage rather than
    /// inserted into it. Keeping it out of the storage is what makes typing safe:
    /// AppKit computes the range it is about to replace before asking the
    /// delegate anything, so text that had to be removed once the user started
    /// typing left that range pointing past the end of the storage.
    var placeholder: NSAttributedString? {
        didSet { setNeedsDisplay(bounds) }
    }

    /// Set by the container whenever the label's content becomes empty or not.
    var isShowingPlaceholder = false {
        didSet {
            guard isShowingPlaceholder != oldValue else { return }
            refreshCaretVisibility()
            setNeedsDisplay(bounds)
        }
    }

    private var hasUserInteracted = false
    private var visibleInsertionPointColor: NSColor?

    /// Marks the user as having taken over the field, which reveals the caret.
    /// Driven by clicks and by text changes rather than by a `keyDown` override,
    /// deliberately keeping this out of the text view's event handling.
    func markUserInteraction() {
        guard !hasUserInteracted else { return }
        hasUserInteracted = true
        refreshCaretVisibility()
    }

    /// The caret is hidden by making it transparent. AppKit owns caret drawing
    /// and blinking; overriding those instead breaks text input on this OS.
    private func refreshCaretVisibility() {
        if visibleInsertionPointColor == nil {
            visibleInsertionPointColor = insertionPointColor
        }

        let shouldHide = isShowingPlaceholder || !hasUserInteracted
        let color = shouldHide ? NSColor.clear : (visibleInsertionPointColor ?? .textColor)
        if insertionPointColor != color {
            insertionPointColor = color
        }
    }

    override func mouseDown(with event: NSEvent) {
        markUserInteraction()
        super.mouseDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard isShowingPlaceholder,
              let placeholder,
              placeholder.length > 0,
              let textContainer else { return }

        // Drawn at the same origin real text would use, so showing and clearing
        // the placeholder never shifts the label's layout.
        let origin = NSPoint(x: textContainerInset.width, y: textContainerInset.height)
        let size = NSSize(
            width: textContainer.containerSize.width,
            height: max(0, bounds.height - origin.y)
        )
        placeholder.draw(with: NSRect(origin: origin, size: size), options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}

final class EditableLabelContainerView: NSView {
    weak var delegate: EditableLabelContainerViewDelegate?
    var textView: NSTextView { labelTextView }
    let previewScale: CGFloat

    private let labelTextView: LegacySelectionTextView

    private var isUpdatingFromCode = false
    private var lastVerticalInset: CGFloat = -1
    private var isUpdatingVerticalAlignment = false
    private var showingPlaceholder = false {
        didSet { labelTextView.isShowingPlaceholder = showingPlaceholder }
    }

    private let autoFitSizer = LabelAutoFitSizer()
    private var isApplyingAutoFit = false
    private var lastReportedFit: LabelAutoFitResult?

    init(previewScale: CGFloat = 1.0) {
        self.previewScale = previewScale
        labelTextView = LegacySelectionTextView(frame: .zero)
        super.init(frame: NSRect(
            x: 0,
            y: 0,
            width: LabelTypography.widthPoints * previewScale,
            height: LabelTypography.heightPoints * previewScale
        ))
        wantsLayer = true
        layer?.cornerRadius = LabelTypography.cornerRadiusPoints * previewScale
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor.white.cgColor
        setupTextView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(
            roundedRect: bounds,
            xRadius: LabelTypography.cornerRadiusPoints * previewScale,
            yRadius: LabelTypography.cornerRadiusPoints * previewScale
        )
        NSColor.white.setFill()
        path.fill()
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
        // Opt out of Writing Tools / the floating Apple Intelligence affordance
        // that macOS shows beside the caret in text views.
        textView.writingToolsBehavior = .none
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.autoresizingMask = [.width, .height]
        textView.delegate = self
        textView.typingAttributes = LabelTypography.attributes(fontSize: scaledFontSize(LabelTypography.defaultMaximumFontSize))

        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = false
            textContainer.heightTracksTextView = false
            textContainer.lineBreakMode = .byWordWrapping
            textContainer.maximumNumberOfLines = 0
            // Zero padding keeps the label's margins exactly the ones in
            // `LabelTypography`, so the on-screen text box matches the printed
            // one and the auto-fit measurements agree with what's drawn.
            textContainer.lineFragmentPadding = 0
            textContainer.containerSize = NSSize(
                width: availableContentSize.width,
                height: .greatestFiniteMagnitude
            )
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

    private var verticalInset: CGFloat {
        LabelTypography.verticalMarginPoints * previewScale
    }

    /// The padded box the text has to live inside, in on-screen points.
    private var availableContentSize: NSSize {
        NSSize(
            width: max(1, labelContentWidth - horizontalInset * 2),
            height: max(1, labelContentHeight - verticalInset * 2)
        )
    }

    /// The ceiling the auto-fit sizer may grow to, in print-accurate points.
    private var maximumFontSize: CGFloat {
        delegate?.preferredStyleState().fontSize ?? LabelTypography.defaultMaximumFontSize
    }

    private var autoSizeEnabled: Bool {
        delegate?.isAutoSizeEnabled() ?? true
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

    /// Rescales the label's text to the largest size that still fits inside the
    /// padded content box. Runs synchronously so a keystroke and its resize land
    /// in the same layout pass, which is what keeps the text from flickering.
    func applyAutoFit() {
        guard !isApplyingAutoFit else { return }

        isApplyingAutoFit = true
        defer { isApplyingAutoFit = false }

        let ceiling = max(LabelTypography.minimumFontSize, maximumFontSize)

        guard let textStorage = textView.textStorage, textStorage.length > 0 else {
            refreshPlaceholder()
            reportFit(LabelAutoFitResult(fontSize: ceiling, fitsWithinBounds: true))
            refreshVerticalAlignment()
            return
        }

        showingPlaceholder = false

        guard autoSizeEnabled else {
            // The user is sizing text by hand, so leave the sizes alone and only
            // report what they add up to and whether it still fits.
            let largest = LabelAutoFitSizer.largestFontSize(in: textStorage) ?? scaledFontSize(ceiling)
            reportFit(LabelAutoFitResult(
                fontSize: logicalFontSize(largest),
                fitsWithinBounds: autoFitSizer.fits(textStorage, in: availableContentSize)
            ))
            refreshVerticalAlignment()
            return
        }

        let result = autoFitSizer.fit(
            textStorage,
            in: availableContentSize,
            previewScale: previewScale,
            sizeRange: LabelTypography.minimumFontSize ... ceiling
        )

        applyFittedFontSize(result.fontSize, to: textStorage)
        reportFit(result)
        refreshVerticalAlignment()
    }

    /// Applies a size the user picked by hand. With text selected it covers the
    /// selection; with nothing selected it covers the whole label, which is what
    /// "make this label smaller" means when no words are highlighted.
    func applyFontSize(_ logicalSize: CGFloat) {
        guard let textStorage = textView.textStorage else { return }

        let selection = safeSelectedRange()
        let target = selection.length > 0
            ? selection
            : NSRange(location: 0, length: textStorage.length)
        let displaySize = scaledFontSize(logicalSize)

        mutateText(in: target) { attributes in
            let font = (attributes[.font] as? NSFont)
                ?? LabelTypography.font(size: displaySize, bold: false, italic: false)
            attributes[.font] = NSFontManager.shared.convert(font, toSize: displaySize)
        }
    }

    /// Scales every run so the largest one lands on `logicalSize`, preserving the
    /// relative sizes of mixed-size text.
    private func applyFittedFontSize(_ logicalSize: CGFloat, to textStorage: NSTextStorage) {
        guard let referenceSize = LabelAutoFitSizer.largestFontSize(in: textStorage), referenceSize > 0 else { return }

        let targetSize = scaledFontSize(logicalSize)
        guard abs(referenceSize - targetSize) > 0.05 else { return }

        let scale = targetSize / referenceSize
        let manager = NSFontManager.shared
        let fullRange = NSRange(location: 0, length: textStorage.length)

        // Resolve every replacement font before mutating, so the storage isn't
        // edited while it is being enumerated.
        var replacements: [(range: NSRange, font: NSFont)] = []
        textStorage.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }

            // Whole points only, rounded down so a rounded-up run can't push the
            // text past the size that measured as fitting. The epsilon keeps a
            // run that lands exactly on a whole size from dropping a point.
            let scaledSize = logicalFontSize(font.pointSize) * scale
            let wholeSize = max(LabelTypography.minimumFontSize, (scaledSize + 0.001).rounded(.down))
            replacements.append((range, manager.convert(font, toSize: scaledFontSize(wholeSize))))
        }
        guard !replacements.isEmpty else { return }

        let savedSelection = textView.selectedRange()

        isUpdatingFromCode = true
        textStorage.beginEditing()
        for replacement in replacements {
            textStorage.addAttribute(.font, value: replacement.font, range: replacement.range)
        }
        textStorage.endEditing()

        // The next character typed has to come in at the new size too, otherwise
        // it would briefly appear at the old size before the next resize.
        var typing = textView.typingAttributes
        if let typingFont = typing[.font] as? NSFont {
            typing[.font] = manager.convert(typingFont, toSize: max(1, typingFont.pointSize * scale))
            textView.typingAttributes = typing
        }

        if savedSelection.location != NSNotFound {
            let location = min(savedSelection.location, textStorage.length)
            let length = min(savedSelection.length, textStorage.length - location)
            textView.setSelectedRange(NSRange(location: location, length: length))
        }
        isUpdatingFromCode = false

        redrawTextView()
    }

    private func reportFit(_ result: LabelAutoFitResult) {
        guard lastReportedFit != result else { return }
        lastReportedFit = result

        // Auto-fit can run inside a layout pass, so hand the result to SwiftUI on
        // the next turn of the run loop rather than mutating observable state
        // while the view hierarchy is mid-update.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.autoFitDidUpdate(
                fontSize: result.fontSize,
                fitsWithinBounds: result.fitsWithinBounds
            )
        }
    }

    /// Keeps the drawn placeholder in step with the label's content and style.
    func refreshPlaceholder() {
        let isEmpty = (textView.textStorage?.length ?? 0) == 0
        showingPlaceholder = isEmpty
        guard isEmpty else { return }

        let style = delegate?.preferredStyleState() ?? LabelEditorStyleState(
            fontSize: LabelTypography.defaultMaximumFontSize,
            isBold: false,
            isItalic: false,
            isUnderlined: false,
            alignment: .center
        )

        let alignment = style.alignment.nsAlignment
        labelTextView.placeholder = LabelTypography.placeholderAttributedString(
            alignment: alignment,
            fontSize: scaledFontSize(LabelTypography.placeholderFontSize)
        )

        // With nothing typed yet, the next character should arrive at the label's
        // current style. Under manual sizing that keeps the size the user chose,
        // rather than snapping back to the auto-size ceiling.
        var attributes = typingAttributes(for: style)
        if !autoSizeEnabled,
           let chosenFont = textView.typingAttributes[.font] as? NSFont,
           let styledFont = attributes[.font] as? NSFont {
            attributes[.font] = NSFontManager.shared.convert(styledFont, toSize: chosenFont.pointSize)
        }

        isUpdatingFromCode = true
        textView.typingAttributes = attributes
        isUpdatingFromCode = false
    }

    func currentStyleState() -> LabelEditorStyleState {
        // Safe even with an empty label: the insertion point falls back to the
        // typing attributes, and the placeholder is no longer part of the storage.
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

        if textStorage.length == 0 {
            // Nothing typed yet: align the placeholder and the typing attributes
            // the first character will pick up.
            applyAlignmentToTypingAttributes(alignment)
            refreshPlaceholder()
            return
        }

        applyAlignmentToAllText(alignment)
        applyAlignmentToTypingAttributes(alignment)
        applyAutoFit()
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
            applyAutoFit()
        }

        let attributedString = upscaledForDisplay(file.makeAttributedString())
        textView.textStorage?.setAttributedString(attributedString)

        if attributedString.length == 0 {
            refreshPlaceholder()
            delegate?.textDidChange("")
            delegate?.selectionDidChange()
            return
        }

        textView.setSelectedRange(NSRange(location: attributedString.length, length: 0))
        updateTypingAttributesFromSelection()
        delegate?.textDidChange(textView.string)
        delegate?.selectionDidChange()
    }

    /// The placeholder is never part of the storage, so the storage is the label's
    /// content, verbatim.
    private var contentPlainText: String {
        textView.string
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

        // Caret with no selection: inherit from the character just before the
        // caret. Reading `typingAttributes` when the caret sits at the end of
        // the storage (the usual case after typing) was returning a stale
        // paragraph style, so the alignment control snapped back to Center and
        // refused to select it again.
        if selection.location > 0 {
            return textStorage.attributes(at: min(selection.location - 1, textStorage.length - 1), effectiveRange: nil)
        }

        return textStorage.attributes(at: 0, effectiveRange: nil)
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

        isUpdatingFromCode = true
        textStorage.beginEditing()
        defer {
            textStorage.endEditing()
            isUpdatingFromCode = false
            updateTypingAttributesFromSelection()
            // Bold and italic change the text's metrics, so the fitted size can
            // change even though no characters were added or removed.
            applyAutoFit()
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

        let fullRange = NSRange(location: 0, length: textStorage.length)
        var replacements: [(range: NSRange, style: NSParagraphStyle)] = []

        // Mutate each existing paragraph style in place so we keep indents and
        // spacing AppKit may have attached, instead of replacing them with a
        // bare style that can trip layout exceptions.
        textStorage.enumerateAttribute(.paragraphStyle, in: fullRange, options: []) { value, range, _ in
            let mutable = ((value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
                ?? NSMutableParagraphStyle()
            mutable.alignment = alignment.nsAlignment
            mutable.lineBreakMode = .byWordWrapping
            replacements.append((range, mutable))
        }

        if replacements.isEmpty {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = alignment.nsAlignment
            paragraphStyle.lineBreakMode = .byWordWrapping
            replacements.append((fullRange, paragraphStyle))
        }

        isUpdatingFromCode = true
        textStorage.beginEditing()
        for replacement in replacements {
            textStorage.addAttribute(.paragraphStyle, value: replacement.style, range: replacement.range)
        }
        textStorage.endEditing()
        isUpdatingFromCode = false
    }

    private func applyAlignmentToTypingAttributes(_ alignment: LabelTextAlignment) {
        var attributes = textView.typingAttributes
        let paragraphStyle = ((attributes[.paragraphStyle] as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
            ?? NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment.nsAlignment
        paragraphStyle.lineBreakMode = .byWordWrapping
        attributes[.paragraphStyle] = paragraphStyle

        isUpdatingFromCode = true
        textView.typingAttributes = attributes
        isUpdatingFromCode = false
    }

    private func refreshVerticalAlignment() {
        guard !isUpdatingVerticalAlignment,
              bounds.height > 0,
              let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager else { return }

        isUpdatingVerticalAlignment = true
        defer { isUpdatingVerticalAlignment = false }

        let savedSelection = safeSelectedRange()

        let contentSize = availableContentSize
        textContainer.containerSize = NSSize(width: contentSize.width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        let usedHeight: CGFloat
        if glyphRange.length > 0 {
            usedHeight = layoutManager.usedRect(for: textContainer).height
        } else if let placeholder = labelTextView.placeholder, placeholder.length > 0 {
            // The placeholder isn't laid out by the text container, so measure it
            // directly to keep it centered exactly like real text.
            usedHeight = placeholder.boundingRect(
                with: NSSize(width: contentSize.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).height
        } else {
            usedHeight = LabelTypography.font(size: scaledFontSize(LabelTypography.defaultFontSize), bold: false, italic: false).boundingRectForFont.height
        }

        let insetX = horizontalInset
        // Never let centering eat into the label's top and bottom margins, even
        // when the text is too long to fit at the smallest allowed size.
        let insetY = max(verticalInset, (bounds.height - usedHeight) / 2)
        let newInset = NSSize(width: insetX, height: insetY)

        if abs(insetY - lastVerticalInset) > 0.25 || textView.textContainerInset != newInset {
            lastVerticalInset = insetY
            isUpdatingFromCode = true
            textView.textContainerInset = newInset
            let clamped = safeSelectedRange()
            // Prefer the pre-layout caret when it still lands inside the storage;
            // otherwise fall back to the clamped range so setSelectedRange never
            // receives an out-of-bounds NSRange after an attribute rewrite.
            let selection = NSMaxRange(savedSelection) <= (textView.textStorage?.length ?? 0)
                ? savedSelection
                : clamped
            textView.setSelectedRange(selection)
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
        applyAutoFit()
    }
}

extension EditableLabelContainerView: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        guard !isUpdatingFromCode else { return }

        // Catches edits that arrive without a key press, such as a menu paste.
        labelTextView.markUserInteraction()

        delegate?.textDidChange(contentPlainText)
        applyAutoFit()
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
