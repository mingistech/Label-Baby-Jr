#if os(macOS)
import AppKit
import SwiftUI

/// Centralized app-wide color styling, so window chrome always matches the
/// SwiftUI content drawn inside it.
enum AppTheme {
    /// A fixed dark slate background (#24292E), used instead of the system's
    /// adaptive `.windowBackgroundColor` because the system's dark mode
    /// background was darker than desired.
    static let windowBackgroundColor = NSColor(
        red: CGFloat(0x24) / 255.0,
        green: CGFloat(0x29) / 255.0,
        blue: CGFloat(0x2E) / 255.0,
        alpha: 1.0
    )

    static let windowBackground = Color(nsColor: windowBackgroundColor)
}
#endif
