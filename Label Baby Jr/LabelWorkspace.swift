#if os(macOS)
import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// Owns the single shared label editor session: the open file (if any), dirty
/// state, and open/save/new so Recent Labels and the editor share one window.
@MainActor
final class LabelWorkspace: ObservableObject {
    static let shared = LabelWorkspace()

    @Published var document = LabelBabyJrDocument()
    @Published private(set) var fileURL: URL?
    @Published private(set) var isDirty = false

    /// Bumped whenever the editor should reload from `document.file` (open/new).
    @Published private(set) var documentEpoch = 0

    /// Set by the editor UI so Save can flush the latest on-screen content
    /// before writing, instead of whatever the last debounced update was.
    var flushEditorContent: (() -> Void)?

    /// Prevents the window-close prompt and the Quit prompt from both asking
    /// in the same shutdown sequence.
    private var closePromptAlreadyHandled = false

    private init() {}

    var displayName: String {
        if let fileURL {
            return fileURL.deletingPathExtension().lastPathComponent
        }
        return "Untitled"
    }

    func noteEditorContentChanged(_ file: LabelBabyJrFile) {
        document.file = file
        isDirty = true
        closePromptAlreadyHandled = false
    }

    func newLabel() {
        flushEditorContent?()
        document = LabelBabyJrDocument()
        fileURL = nil
        isDirty = false
        documentEpoch += 1
    }

    func openLabel(at url: URL) {
        let normalized = url.standardizedFileURL
        if fileURL?.standardizedFileURL == normalized, !isDirty {
            return
        }
        // Prefer the already-decoded sidebar preview when we have it so opening
        // a recent doesn't wait on another disk read.
        if let item = RecentLabelsStore.shared.items.first(where: {
            $0.url.standardizedFileURL == normalized
        }) {
            openLabel(item)
            return
        }
        load(from: url)
    }

    /// Opens a recent item from its in-memory preview — no save prompt, no
    /// disk round-trip, no full recent-list reload.
    func openLabel(_ item: RecentLabelItem) {
        let normalized = item.url.standardizedFileURL
        if fileURL?.standardizedFileURL == normalized, !isDirty {
            return
        }

        document = LabelBabyJrDocument(file: item.previewFile)
        fileURL = normalized
        isDirty = false
        documentEpoch += 1
        RecentLabelsStore.shared.promote(item)
    }

    func openInteractive() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.labelBabyJr]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        load(from: url)
    }

    @discardableResult
    func save() -> Bool {
        flushEditorContent?()
        if let fileURL {
            return write(to: fileURL)
        }
        return saveAs()
    }

    @discardableResult
    func saveAs() -> Bool {
        flushEditorContent?()
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.labelBabyJr]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = displayName == "Untitled" ? "Label" : displayName
        guard panel.runModal() == .OK, let url = panel.url else { return false }
        return write(to: url)
    }

    private func load(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let file = try LabelBabyJrFile.decoded(from: data)
            document = LabelBabyJrDocument(file: file)
            fileURL = url.standardizedFileURL
            isDirty = false
            documentEpoch += 1
            RecentLabelsStore.shared.recordDocument(at: url, file: file)
        } catch {
            presentError(error, title: "Couldn’t Open Label")
        }
    }

    private func write(to url: URL) -> Bool {
        do {
            let data = try document.file.encodedData()
            try data.write(to: url, options: .atomic)
            fileURL = url.standardizedFileURL
            isDirty = false
            RecentLabelsStore.shared.recordDocument(at: url, file: document.file)
            return true
        } catch {
            presentError(error, title: "Couldn’t Save Label")
            return false
        }
    }

    /// Returns `false` when the user cancels closing with unsaved changes.
    func confirmCloseIfNeeded() -> Bool {
        // Closing the last window triggers both `windowShouldClose` and then
        // `applicationShouldTerminate`; only the first should present a dialog.
        if closePromptAlreadyHandled {
            return true
        }

        let wasDirty = isDirty
        flushEditorContent?()
        // Flushing syncs `document.file` through the editor callback, which
        // would otherwise mark a clean (or already-dismissed) document dirty
        // again and pop a second save dialog on Quit.
        if !wasDirty {
            isDirty = false
        }

        guard isDirty else {
            closePromptAlreadyHandled = true
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes you made to \(displayName)?"
        alert.informativeText = "Your changes will be lost if you don’t save them."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don’t Save")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            let saved = save()
            if saved {
                closePromptAlreadyHandled = true
            }
            return saved
        case .alertSecondButtonReturn:
            isDirty = false
            closePromptAlreadyHandled = true
            return true
        default:
            return false
        }
    }

    private func presentError(_ error: Error, title: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
#endif
