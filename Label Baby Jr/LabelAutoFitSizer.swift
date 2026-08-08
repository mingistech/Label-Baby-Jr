#if os(macOS)
import AppKit

struct LabelAutoFitResult: Equatable {
    /// Print-accurate point size chosen for the label's largest run of text.
    var fontSize: CGFloat
    /// `false` when the text still does not fit at the smallest allowed size.
    var fitsWithinBounds: Bool
}

/// Finds the largest font size at which a label's text still fits inside the
/// available space, by laying the text out and measuring it rather than
/// estimating from character counts.
///
/// Measurement happens in the editor's on-screen (scaled) space, while the
/// returned size is in print-accurate points, so callers pass in both the
/// already-padded content box and the preview zoom factor.
///
/// The TextKit stack here is private to the sizer, so probing candidate sizes
/// never disturbs the live editor's layout, selection, or undo stack.
final class LabelAutoFitSizer {
    private let textStorage = NSTextStorage()
    private let layoutManager = NSLayoutManager()
    private let textContainer = NSTextContainer(size: .zero)

    init() {
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        textContainer.maximumNumberOfLines = 0
        layoutManager.usesFontLeading = true
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
    }

    func fit(
        _ source: NSAttributedString,
        in availableSize: NSSize,
        previewScale: CGFloat,
        sizeRange: ClosedRange<CGFloat>,
        quantum: CGFloat = LabelTypography.fontSizeQuantum
    ) -> LabelAutoFitResult {
        guard source.length > 0,
              availableSize.width > 0,
              availableSize.height > 0,
              previewScale > 0,
              let referenceSize = Self.largestFontSize(in: source),
              referenceSize > 0
        else {
            return LabelAutoFitResult(fontSize: sizeRange.upperBound, fitsWithinBounds: true)
        }

        // Sizes are searched for the largest run, and the others follow by ratio,
        // so the floor has to be raised enough that the *smallest* run also stays
        // at or above the readable minimum.
        let smallestRatio = max((Self.smallestFontSize(in: source) ?? referenceSize) / referenceSize, 0.01)
        let readableFloor = min(sizeRange.lowerBound / smallestRatio, sizeRange.upperBound)
        let searchRange = readableFloor ... sizeRange.upperBound

        let candidates = Self.candidateSizes(in: searchRange, quantum: quantum)

        // A larger font never occupies less space, so "does this size fit" is
        // monotonic across the candidate list and a binary search is safe.
        var low = 0
        var high = candidates.count - 1
        var largestFitting: CGFloat?

        while low <= high {
            let middle = (low + high) / 2
            let candidate = candidates[middle]
            let fits = self.fits(
                source,
                referenceSize: referenceSize,
                candidate: candidate,
                availableSize: availableSize,
                previewScale: previewScale
            )

            if fits {
                largestFitting = candidate
                low = middle + 1
            } else {
                high = middle - 1
            }
        }

        if let largestFitting {
            return LabelAutoFitResult(fontSize: largestFitting, fitsWithinBounds: true)
        }

        return LabelAutoFitResult(
            fontSize: candidates.first ?? searchRange.lowerBound,
            fitsWithinBounds: false
        )
    }

    /// Reports whether `source` fits at the sizes it already carries. Used when
    /// the user is sizing text by hand, to warn without changing anything.
    func fits(_ source: NSAttributedString, in availableSize: NSSize) -> Bool {
        guard source.length > 0 else { return true }
        return fitsWhenLaidOut(source, in: availableSize)
    }

    /// Scales `source` so its largest run renders at `candidate` points and
    /// reports whether the laid-out result stays inside `availableSize`.
    private func fits(
        _ source: NSAttributedString,
        referenceSize: CGFloat,
        candidate: CGFloat,
        availableSize: NSSize,
        previewScale: CGFloat
    ) -> Bool {
        let scale = (candidate * previewScale) / referenceSize
        return fitsWhenLaidOut(Self.scaled(source, by: scale), in: availableSize)
    }

    private func fitsWhenLaidOut(_ candidate: NSAttributedString, in availableSize: NSSize) -> Bool {
        textStorage.setAttributedString(candidate)
        textContainer.size = NSSize(width: availableSize.width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)

        let used = layoutManager.usedRect(for: textContainer).size

        // Width is checked too: a single unbreakable word can be wider than the
        // container even though word wrapping had nothing to break.
        let tolerance: CGFloat = 0.05
        return used.width <= availableSize.width + tolerance
            && used.height <= availableSize.height + tolerance
    }

    static func largestFontSize(in source: NSAttributedString) -> CGFloat? {
        var largest: CGFloat?
        let fullRange = NSRange(location: 0, length: source.length)
        source.enumerateAttribute(.font, in: fullRange, options: []) { value, _, _ in
            guard let font = value as? NSFont else { return }
            largest = max(largest ?? 0, font.pointSize)
        }
        return largest
    }

    static func smallestFontSize(in source: NSAttributedString) -> CGFloat? {
        var smallest: CGFloat?
        let fullRange = NSRange(location: 0, length: source.length)
        source.enumerateAttribute(.font, in: fullRange, options: []) { value, _, _ in
            guard let font = value as? NSFont else { return }
            smallest = min(smallest ?? .greatestFiniteMagnitude, font.pointSize)
        }
        return smallest
    }

    /// Multiplies every font size by `scale`, preserving the relative sizes of
    /// runs so mixed-size text keeps its proportions as the label rescales.
    static func scaled(_ source: NSAttributedString, by scale: CGFloat) -> NSAttributedString {
        guard scale != 1, source.length > 0 else { return source }

        let result = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: result.length)
        result.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            guard let font = value as? NSFont else { return }
            let scaledSize = max(1, font.pointSize * scale)
            result.addAttribute(.font, value: NSFontManager.shared.convert(font, toSize: scaledSize), range: range)
        }
        return result
    }

    private static func candidateSizes(in range: ClosedRange<CGFloat>, quantum: CGFloat) -> [CGFloat] {
        let step = max(1, quantum.rounded())

        // Whole points only: start at the first whole size at or above the floor
        // so a fitted size is never fractional.
        var sizes: [CGFloat] = []
        var size = range.lowerBound.rounded(.up)
        while size <= range.upperBound {
            sizes.append(size)
            size += step
        }

        if sizes.isEmpty {
            sizes.append(max(1, range.upperBound.rounded(.down)))
        }
        return sizes
    }
}
#endif
