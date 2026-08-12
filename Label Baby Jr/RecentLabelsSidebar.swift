#if os(macOS)
import SwiftUI

/// Vertical, scrollable list of recent label previews shown beside the editor.
/// A single click highlights immediately; a second click within the double-click
/// interval opens the label. Manual timing avoids SwiftUI's tap-gesture delay.
struct RecentLabelsSidebar: View {
    private let thumbnailScale: CGFloat = 1.05
    private let horizontalPadding: CGFloat = 14

    /// The label currently loaded in the editor, if any.
    var openURL: URL?
    var height: CGFloat
    var onOpen: (RecentLabelItem) -> Void

    @EnvironmentObject private var recentLabels: RecentLabelsStore
    @State private var highlightedURL: URL?

    var sidebarWidth: CGFloat {
        LabelTypography.widthPoints * thumbnailScale + horizontalPadding * 2
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recents")
                .font(AppTheme.sectionHeaderFont)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 4)

            if recentLabels.items.isEmpty {
                Text("Saved labels will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, horizontalPadding)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(recentLabels.items) { item in
                            RecentLabelRow(
                                item: item,
                                thumbnailScale: thumbnailScale,
                                isHighlighted: highlightedURL?.standardizedFileURL == item.url.standardizedFileURL,
                                onHighlight: {
                                    highlightedURL = item.url.standardizedFileURL
                                },
                                onOpen: {
                                    highlightedURL = item.url.standardizedFileURL
                                    onOpen(item)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(width: sidebarWidth, height: height, alignment: .topLeading)
        .onAppear {
            recentLabels.refresh()
            highlightedURL = openURL?.standardizedFileURL
        }
        .onChange(of: openURL) { _, url in
            highlightedURL = url?.standardizedFileURL
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Cheap reorder/cache reuse only; full disk reads happen for unknown URLs.
            recentLabels.refresh()
        }
    }
}

private struct RecentLabelRow: View {
    let item: RecentLabelItem
    let thumbnailScale: CGFloat
    let isHighlighted: Bool
    let onHighlight: () -> Void
    let onOpen: () -> Void

    /// Manual double-click window so the first click can highlight without
    /// waiting for SwiftUI's multi-tap recognizer timeout (~300ms).
    @State private var lastClickAt: Date?

    var body: some View {
        VStack(spacing: 8) {
            LabelThumbnailView(
                attributedString: item.previewAttributedString,
                previewScale: thumbnailScale
            )
            .equatable()

            Text(item.displayName)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHighlighted ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isHighlighted ? Color.accentColor.opacity(0.55) : Color.clear,
                    lineWidth: 1
                )
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: handleClick)
        .help("\(item.displayName) — double-click to open")
    }

    private func handleClick() {
        let now = Date()
        if let lastClickAt, now.timeIntervalSince(lastClickAt) < 0.35 {
            self.lastClickAt = nil
            onOpen()
        } else {
            lastClickAt = now
            onHighlight()
        }
    }
}
#endif
