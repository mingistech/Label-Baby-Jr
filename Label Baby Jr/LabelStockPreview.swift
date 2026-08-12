#if os(macOS)
import SwiftUI

/// The on-screen chrome for an 89×28mm DYMO address label: white stock clipped
/// to the die-cut silhouette, with a light edge and shadow so it reads as a
/// physical label rather than a plain text field.
struct LabelStockPreview<Content: View>: View {
    var previewScale: CGFloat = 1
    var borderColor: Color = Color.black.opacity(0.14)
    var showsShadow: Bool = true
    @ViewBuilder var content: () -> Content

    private var previewWidth: CGFloat { LabelTypography.widthPoints * previewScale }
    private var previewHeight: CGFloat { LabelTypography.heightPoints * previewScale }
    private var cornerRadius: CGFloat { LabelTypography.cornerRadiusPoints * previewScale }

    var body: some View {
        content()
            .frame(width: previewWidth, height: previewHeight)
            .background(Color.white)
            .clipShape(labelShape)
            .overlay {
                labelShape
                    .strokeBorder(borderColor, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .compositingGroup()
            .shadow(
                color: showsShadow ? .black.opacity(0.32) : .clear,
                radius: showsShadow ? 7 : 0,
                y: showsShadow ? 3 : 0
            )
    }

    private var labelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}
#endif
