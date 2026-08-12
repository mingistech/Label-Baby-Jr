#if os(macOS)
import AppKit
import Combine

struct RecentLabelItem: Identifiable, Equatable {
    var id: URL { url }
    let url: URL
    let displayName: String
    let previewFile: LabelBabyJrFile
    /// Pre-rendered once when the item is built so sidebar redraws don't rebuild
    /// attributed strings on every highlight change.
    let previewAttributedString: NSAttributedString

    static func == (lhs: RecentLabelItem, rhs: RecentLabelItem) -> Bool {
        lhs.url.standardizedFileURL == rhs.url.standardizedFileURL
            && lhs.displayName == rhs.displayName
            && lhs.previewFile == rhs.previewFile
    }

    init(url: URL, displayName: String, previewFile: LabelBabyJrFile) {
        self.url = url
        self.displayName = displayName
        self.previewFile = previewFile
        self.previewAttributedString = previewFile.makeAttributedString()
    }
}

@MainActor
final class RecentLabelsStore: ObservableObject {
    static let shared = RecentLabelsStore()

    static let maxRecentCount = 12
    private static let bookmarksKey = "recentLabelBookmarks"

    @Published private(set) var items: [RecentLabelItem] = []

    private init() {}

    func refresh() {
        var urls = Self.loadBookmarkedURLs()

        if let openURL = LabelWorkspace.shared.fileURL {
            let normalized = openURL.standardizedFileURL
            urls.removeAll { $0.standardizedFileURL == normalized }
            urls.insert(openURL, at: 0)
        }

        urls = Array(urls.prefix(Self.maxRecentCount))

        // Reuse already-decoded previews whenever the URL hasn't changed, so a
        // refresh after opening one label doesn't re-read every recent file.
        let existing = Dictionary(uniqueKeysWithValues: items.map {
            ($0.url.standardizedFileURL, $0)
        })
        items = urls.map { url in
            let normalized = url.standardizedFileURL
            if let cached = existing[normalized] {
                return cached
            }
            return makeItem(for: url)
        }
        Self.saveBookmarkedURLs(urls)
    }

    /// Moves an already-loaded item to the top without touching the disk.
    func promote(_ item: RecentLabelItem) {
        let normalized = item.url.standardizedFileURL
        var next = items.filter { $0.url.standardizedFileURL != normalized }
        next.insert(item, at: 0)
        if next.count > Self.maxRecentCount {
            next = Array(next.prefix(Self.maxRecentCount))
        }
        items = next
        Self.saveBookmarkedURLs(next.map(\.url))
        NSDocumentController.shared.noteNewRecentDocumentURL(item.url)
    }

    func recordDocument(at url: URL, file: LabelBabyJrFile? = nil) {
        let normalized = url.standardizedFileURL
        let item: RecentLabelItem
        if let file {
            item = RecentLabelItem(
                url: url,
                displayName: url.deletingPathExtension().lastPathComponent,
                previewFile: file
            )
        } else if let existing = items.first(where: { $0.url.standardizedFileURL == normalized }) {
            item = existing
        } else {
            item = makeItem(for: url)
        }
        promote(item)
    }

    private func makeItem(for url: URL) -> RecentLabelItem {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let displayName = url.deletingPathExtension().lastPathComponent
        guard let data = try? Data(contentsOf: url),
              let file = try? LabelBabyJrFile.decoded(from: data) else {
            return RecentLabelItem(url: url, displayName: displayName, previewFile: .empty)
        }

        return RecentLabelItem(url: url, displayName: displayName, previewFile: file)
    }

    private static func loadBookmarkedURLs() -> [URL] {
        if let bookmarkData = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] {
            let resolved = bookmarkData.compactMap { resolveBookmark($0) }
            if !resolved.isEmpty {
                return resolved
            }
        }

        return NSDocumentController.shared.recentDocumentURLs
            .filter { $0.pathExtension.lowercased() == "labelbabyjr" }
    }

    private static func saveBookmarkedURLs(_ urls: [URL]) {
        let bookmarks = urls.compactMap { url in
            try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
    }

    private static func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }
}
#endif
