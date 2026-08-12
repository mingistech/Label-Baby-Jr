#if os(macOS)
import AppKit
import SwiftUI

/// Locks the window to the content's natural size and removes visible title bar chrome.
struct WindowFrameConfigurator: NSViewRepresentable {
    /// When true, closing this window asks to save if the label has unsaved edits.
    var promptsToSaveOnClose = false

    private final class WindowState {
        var didConfigureChrome = false
        var appliedSize = NSSize.zero
        var closeDelegate: ClosePromptDelegate?
    }

    final class ClosePromptDelegate: NSObject, NSWindowDelegate {
        func windowShouldClose(_ sender: NSWindow) -> Bool {
            LabelWorkspace.shared.confirmCloseIfNeeded()
        }
    }

    private static var states = NSMapTable<NSWindow, WindowState>.weakToStrongObjects()

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureWindow(for: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(for: nsView)
        }
    }

    private func state(for window: NSWindow) -> WindowState {
        if let existing = Self.states.object(forKey: window) {
            return existing
        }

        let state = WindowState()
        Self.states.setObject(state, forKey: window)
        return state
    }

    private func configureWindow(for view: NSView) {
        guard let window = view.window,
              let contentView = window.contentView else { return }

        let state = state(for: window)

        if !state.didConfigureChrome {
            window.styleMask.insert(.fullSizeContentView)
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.titlebarSeparatorStyle = .none
            window.isMovableByWindowBackground = true
            state.didConfigureChrome = true
        }

        // Dynamic AppTheme color — reapply so Light / Dark / System switches
        // refresh the titlebar fill, not only the SwiftUI content.
        window.backgroundColor = AppTheme.windowBackgroundColor


        if promptsToSaveOnClose, state.closeDelegate == nil {
            let delegate = ClosePromptDelegate()
            state.closeDelegate = delegate
            window.delegate = delegate
        }

        contentView.layoutSubtreeIfNeeded()
        let fittingSize = contentView.fittingSize
        guard fittingSize.width > 0, fittingSize.height > 0 else { return }

        let targetSize = NSSize(width: fittingSize.width, height: fittingSize.height)
        guard !sizesAreEqual(state.appliedSize, targetSize) else { return }

        state.appliedSize = targetSize
        window.setContentSize(targetSize)
        window.minSize = targetSize
        window.maxSize = targetSize
    }

    private func sizesAreEqual(_ lhs: NSSize, _ rhs: NSSize) -> Bool {
        abs(lhs.width - rhs.width) < 0.5 && abs(lhs.height - rhs.height) < 0.5
    }
}
#endif // os(macOS)
