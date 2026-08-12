#if os(macOS)
import AppKit
import SwiftUI

struct LabelThumbnailView: View, Equatable {
    let attributedString: NSAttributedString
    var previewScale: CGFloat = 1.0

    static func == (lhs: LabelThumbnailView, rhs: LabelThumbnailView) -> Bool {
        lhs.previewScale == rhs.previewScale && lhs.attributedString.isEqual(rhs.attributedString)
    }

    var body: some View {
        LabelStockPreview(
            previewScale: previewScale,
            borderColor: Color.secondary.opacity(0.35),
            showsShadow: false
        ) {
            LabelPrintViewRepresentable(attributedString: attributedString)
                .frame(width: LabelTypography.widthPoints, height: LabelTypography.heightPoints)
                .scaleEffect(previewScale, anchor: .center)
        }
    }
}

private struct LabelPrintViewRepresentable: NSViewRepresentable {
    let attributedString: NSAttributedString

    func makeNSView(context: Context) -> LabelPrintView {
        LabelPrintView(attributedString: attributedString)
    }

    func updateNSView(_ nsView: LabelPrintView, context: Context) {
        // Pointer equality is enough: RecentLabelItem caches one attributed
        // string per preview, so highlight-only redraws skip this work.
        guard nsView.attributedString !== attributedString else { return }
        nsView.attributedString = attributedString
        nsView.needsDisplay = true
    }
}
#endif
