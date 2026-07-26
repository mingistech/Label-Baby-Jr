#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers

struct LabelBabyJrDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.labelBabyJr] }
    static var writableContentTypes: [UTType] { [.labelBabyJr] }

    var file: LabelBabyJrFile

    init(file: LabelBabyJrFile = .empty) {
        self.file = file
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        file = try LabelBabyJrFile.decoded(from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try file.encodedData())
    }
}
#endif
