#if os(macOS)
import AppKit

enum LabelTextAlignment: String, CaseIterable, Identifiable, Codable {
    case left
    case center
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: "Left"
        case .center: "Center"
        case .right: "Right"
        }
    }

    var nsAlignment: NSTextAlignment {
        switch self {
        case .left: .left
        case .center: .center
        case .right: .right
        }
    }

    init(nsAlignment: NSTextAlignment) {
        switch nsAlignment {
        case .left, .natural:
            self = .left
        case .right:
            self = .right
        default:
            self = .center
        }
    }
}

enum LabelTypography {
    static let widthMillimeters: CGFloat = 89
    static let heightMillimeters: CGFloat = 28
    static let widthPoints = widthMillimeters * 72.0 / 25.4
    static let heightPoints = heightMillimeters * 72.0 / 25.4
    static let fontFamily = "Helvetica"
    static let defaultFontSize: CGFloat = 14
    static let placeholderText = "Type here"

    /// Hint size for the empty-label placeholder. Kept well below the auto-fit
    /// ceiling so "Type here" reads as guidance rather than filling the stock.
    static let placeholderFontSize: CGFloat = 25

    /// A fixed gray rather than a dynamic system color: the label is always white
    /// paper, so a color that adapts to the app's dark theme would render nearly
    /// invisible on it.
    static let placeholderColor = NSColor(white: 0.62, alpha: 1)

    /// Bounds for the auto-fit sizer, in print-accurate points. Text is drawn as
    /// large as will fit up to the user's chosen ceiling, and never shrinks past
    /// `minimumFontSize` so a printed label always stays readable.
    static let minimumFontSize: CGFloat = 8
    static let maximumFontSize: CGFloat = 72
    static let defaultMaximumFontSize: CGFloat = 52

    /// Auto-fit searches whole point sizes only. Quantizing keeps the chosen size
    /// stable between keystrokes, which is what prevents the text from visibly
    /// twitching as the measured size crosses a threshold.
    static let fontSizeQuantum: CGFloat = 1

    /// Die-cut corner radius of a standard DYMO 89×28mm address label (~3.5mm).
    /// The preview silhouette and the text safe-area both key off this value.
    static let cornerRadiusMillimeters: CGFloat = 3.5
    static let cornerRadiusPoints = cornerRadiusMillimeters * 72.0 / 25.4

    /// Left/right inset for editable and printed text. Matches the corner radius
    /// so the text box ends where the die-cut curve begins, instead of running
    /// into the rounded ends of the label.
    static let horizontalMarginPoints: CGFloat = cornerRadiusPoints

    /// Top/bottom inset for editable and printed text. Kept small so Auto fit
    /// can still use most of the label's height.
    static let verticalMarginPoints: CGFloat = 2

    static func font(size: CGFloat, bold: Bool, italic: Bool) -> NSFont {
        var traits: NSFontTraitMask = []
        if bold { traits.insert(.boldFontMask) }
        if italic { traits.insert(.italicFontMask) }

        return NSFontManager.shared.font(
            withFamily: fontFamily,
            traits: traits,
            weight: bold ? 9 : 5,
            size: size
        ) ?? NSFont(name: "Helvetica", size: size)
            ?? NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    static func attributes(
        fontSize: CGFloat,
        bold: Bool = false,
        italic: Bool = false,
        underlined: Bool = false,
        alignment: NSTextAlignment = .center,
        foregroundColor: NSColor = .black
    ) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byWordWrapping

        var attributes: [NSAttributedString.Key: Any] = [
            .font: font(size: fontSize, bold: bold, italic: italic),
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraphStyle,
        ]

        if underlined {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }

        return attributes
    }

    static func placeholderAttributedString(
        alignment: NSTextAlignment = .center,
        fontSize: CGFloat = defaultFontSize
    ) -> NSAttributedString {
        NSAttributedString(
            string: placeholderText,
            attributes: attributes(
                fontSize: fontSize,
                alignment: alignment,
                foregroundColor: placeholderColor
            )
        )
    }
}
#endif
