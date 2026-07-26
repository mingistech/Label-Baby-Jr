#if os(macOS)
import AppKit
import SwiftUI

struct LabelThumbnailView: View {
    let file: LabelBabyJrFile
    var previewScale: CGFloat = 1.0

    var body: some View {
        let previewWidth = LabelTypography.widthPoints * previewScale
        let previewHeight = LabelTypography.heightPoints * previewScale

        LabelPrintViewRepresentable(attributedString: file.makeAttributedString())
            .frame(width: LabelTypography.widthPoints, height: LabelTypography.heightPoints)
            .scaleEffect(previewScale, anchor: .center)
            .frame(width: previewWidth, height: previewHeight)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.secondary.opacity(0.35), lineWidth: 1)
            }
    }
}

private struct LabelPrintViewRepresentable: NSViewRepresentable {
    let attributedString: NSAttributedString

    func makeNSView(context: Context) -> LabelPrintView {
        LabelPrintView(attributedString: attributedString)
    }

    func updateNSView(_ nsView: LabelPrintView, context: Context) {}
}
#endif
