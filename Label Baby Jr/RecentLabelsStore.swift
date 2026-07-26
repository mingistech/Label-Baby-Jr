#if os(macOS)
import AppKit
import Combine

struct RecentLabelItem: Identifiable {
    var id: URL { url }
    let url: URL
    let displayName: String
    let previewFile: LabelBabyJrFile
}

@MainActor
final class RecentLabelsStore: ObservableObject {
    static let shared = RecentLabelsStore()

    static let maxRecentCount = 6
    private static let bookmarksKey = "recentLabelBookmarks"

    @Published private(set) var items: [RecentLabelItem] = []

    private init() {}

    func refresh() {
        // Merge in the URLs of any currently-open label windows. This makes the
        // list self-healing: SwiftUI's `DocumentGroup` configuration doesn't
        // always re-notify an already-rendered view when a brand-new document
        // is saved for the first time, so relying solely on the explicit
        // `recordDocument` call can miss recently created labels. The live
        // document list is always accurate, since it comes straight from
        // AppKit rather than a SwiftUI snapshot.
        var urls = Self.loadBookmarkedURLs()
        for url in Self.currentlyOpenLabelURLs().reversed() {
            let normalized = url.standardizedFileURL
            urls.removeAll { $0.standardizedFileURL == normalized }
            urls.insert(url, at: 0)
        }
        urls = Array(urls.prefix(Self.maxRecentCount))

        items = urls.map { item(for: $0) }
        Self.saveBookmarkedURLs(urls)
    }

    private static func currentlyOpenLabelURLs() -> [URL] {
        NSDocumentController.shared.documents.compactMap { document in
            guard let url = document.fileURL, url.pathExtension.lowercased() == "labelbabyjr" else { return nil }
            return url
        }
    }

    func recordDocument(at url: URL) {
        var urls = Self.loadBookmarkedURLs()
        let normalized = url.standardizedFileURL
        urls.removeAll { $0.standardizedFileURL == normalized }
        urls.insert(url, at: 0)
        Self.saveBookmarkedURLs(Array(urls.prefix(Self.maxRecentCount)))
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        refresh()
    }

    private func item(for url: URL) -> RecentLabelItem {
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
