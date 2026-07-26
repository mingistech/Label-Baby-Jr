#if os(macOS)
import AppKit

final class LabelPrintView: NSView {
    var attributedString: NSAttributedString

    init(attributedString: NSAttributedString) {
        self.attributedString = attributedString
        super.init(frame: NSRect(x: 0, y: 0, width: LabelTypography.widthPoints, height: LabelTypography.heightPoints))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()

        guard attributedString.length > 0 else { return }

        let insetBounds = bounds.insetBy(
            dx: LabelTypography.horizontalMarginPoints,
            dy: LabelTypography.verticalMarginPoints
        )
        let textSize = attributedString.boundingRect(
            with: NSSize(width: insetBounds.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        ).size

        let yOffset = max(0, (insetBounds.height - textSize.height) / 2)
        let drawRect = NSRect(
            x: insetBounds.minX,
            y: insetBounds.minY + yOffset,
            width: insetBounds.width,
            height: min(textSize.height, insetBounds.height)
        )

        attributedString.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}
#endif
