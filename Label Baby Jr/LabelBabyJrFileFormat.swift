#if os(macOS)
import AppKit

struct LabelSize: Codable, Equatable {
    var widthMM: Double
    var heightMM: Double

    static let standard = LabelSize(
        widthMM: Double(LabelTypography.widthMillimeters),
        heightMM: Double(LabelTypography.heightMillimeters)
    )
}

struct LabelRun: Codable, Equatable {
    var text: String
    var fontSize: Double
    var bold: Bool
    var italic: Bool
    var underline: Bool
    var alignment: LabelTextAlignment
}

struct LabelBabyJrFile: Codable, Equatable {
    static let currentFormatVersion = 1

    var formatVersion: Int
    var labelSize: LabelSize
    var runs: [LabelRun]

    static let empty = LabelBabyJrFile(
        formatVersion: currentFormatVersion,
        labelSize: .standard,
        runs: []
    )

    init(formatVersion: Int, labelSize: LabelSize, runs: [LabelRun]) {
        self.formatVersion = formatVersion
        self.labelSize = labelSize
        self.runs = runs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decode(Int.self, forKey: .formatVersion)
        guard formatVersion <= Self.currentFormatVersion else {
            throw LabelBabyJrFileError.unsupportedFormatVersion(formatVersion)
        }
        labelSize = try container.decode(LabelSize.self, forKey: .labelSize)
        runs = try container.decode([LabelRun].self, forKey: .runs)
    }

    func encodedData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decoded(from data: Data) throws -> LabelBabyJrFile {
        let decoder = JSONDecoder()
        return try decoder.decode(LabelBabyJrFile.self, from: data)
    }

    func makeAttributedString() -> NSAttributedString {
        let result = NSMutableAttributedString()
        for run in runs where !run.text.isEmpty {
            let attributes = LabelTypography.attributes(
                fontSize: CGFloat(run.fontSize),
                bold: run.bold,
                italic: run.italic,
                underlined: run.underline,
                alignment: run.alignment.nsAlignment
            )
            result.append(NSAttributedString(string: run.text, attributes: attributes))
        }
        return result
    }

    static func from(attributedString: NSAttributedString) -> LabelBabyJrFile {
        LabelBabyJrFile(
            formatVersion: currentFormatVersion,
            labelSize: .standard,
            runs: runs(from: attributedString)
        )
    }

    static func runs(from attributedString: NSAttributedString) -> [LabelRun] {
        guard attributedString.length > 0 else { return [] }

        var runs: [LabelRun] = []
        let fullRange = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            let text = attributedString.attributedSubstring(from: range).string
            guard !text.isEmpty else { return }

            let font = (attributes[.font] as? NSFont)
                ?? LabelTypography.font(size: LabelTypography.defaultFontSize, bold: false, italic: false)
            let traits = NSFontManager.shared.traits(of: font)
            let underline = (attributes[.underlineStyle] as? Int) == NSUnderlineStyle.single.rawValue
            let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle

            runs.append(
                LabelRun(
                    text: text,
                    fontSize: Double(font.pointSize),
                    bold: traits.contains(.boldFontMask),
                    italic: traits.contains(.italicFontMask),
                    underline: underline,
                    alignment: LabelTextAlignment(nsAlignment: paragraph?.alignment ?? .center)
                )
            )
        }

        return runs
    }
}

enum LabelBabyJrFileError: LocalizedError {
    case unsupportedFormatVersion(Int)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormatVersion(let version):
            "This label file uses format version \(version), which is newer than this app supports."
        }
    }
}
#endif
