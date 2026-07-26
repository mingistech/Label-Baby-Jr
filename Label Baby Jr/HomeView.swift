#if os(macOS)
import AppKit
import SwiftUI

struct HomeView: View {
    private let thumbnailScale: CGFloat = 1.5
    private let horizontalPadding: CGFloat = 24
    private let columnSpacing: CGFloat = 20
    private let columnCount: CGFloat = 2

    private var windowWidth: CGFloat {
        let thumbnailWidth = LabelTypography.widthPoints * thumbnailScale
        return horizontalPadding * 2 + columnSpacing * (columnCount - 1) + thumbnailWidth * columnCount
    }

    private var recentLabelsHeaderFont: Font {
        let size = NSFont.preferredFont(forTextStyle: .headline).pointSize * 2
        return .system(size: size, weight: .semibold)
    }

    @EnvironmentObject private var recentLabels: RecentLabelsStore
    @Environment(\.dismissWindow) private var dismissWindow

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: columnSpacing),
            GridItem(.flexible(), spacing: columnSpacing),
        ]
    }

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.windowBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                recentLabelsSection
                createLabelButton
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, 28)
            .padding(.top, 20)

            HStack {
                Spacer()
                SettingsToolbarButton()
            }
            .padding(.top, 10)
            .padding(.trailing, 16)
        }
        .frame(width: windowWidth, alignment: .topLeading)
        .fixedSize(horizontal: true, vertical: true)
        .background(WindowFrameConfigurator())
        .onAppear {
            recentLabels.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            recentLabels.refresh()
        }
    }

    private var recentLabelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Labels")
                .font(recentLabelsHeaderFont)

            if recentLabels.items.isEmpty {
                Text("Saved labels will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(recentLabels.items) { item in
                        recentLabelButton(for: item)
                    }
                }
            }
        }
    }

    private func recentLabelButton(for item: RecentLabelItem) -> some View {
        Button {
            openRecentLabel(item)
        } label: {
            VStack(spacing: 10) {
                LabelThumbnailView(file: item.previewFile, previewScale: thumbnailScale)
                    .frame(maxWidth: .infinity)

                Text(item.displayName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var createLabelButton: some View {
        Button("Create New Label") {
            createNewLabel()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private func openRecentLabel(_ item: RecentLabelItem) {
        LabelDocumentActions.openLabel(at: item.url)
        dismissHomeWindow()
    }

    private func createNewLabel() {
        LabelDocumentActions.createNewLabel()
        dismissHomeWindow()
    }

    private func dismissHomeWindow() {
        dismissWindow(id: "home")
    }
}

#Preview {
    HomeView()
        .environmentObject(RecentLabelsStore.shared)
}
#endif
