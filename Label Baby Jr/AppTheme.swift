#if os(macOS)
import AppKit
import SwiftUI

/// Centralized app-wide color styling, so window chrome always matches the
/// SwiftUI content drawn inside it.
enum AppTheme {
    /// Dark slate (#24292E). Chosen instead of the system's adaptive dark
    /// window background, which was darker than desired.
    private static let darkWindowBackgroundColor = NSColor(
        red: CGFloat(0x24) / 255.0,
        green: CGFloat(0x29) / 255.0,
        blue: CGFloat(0x2E) / 255.0,
        alpha: 1.0
    )

    /// Soft gray (#F0F2F4) so white label stock still contrasts in Light mode.
    private static let lightWindowBackgroundColor = NSColor(
        red: CGFloat(0xF0) / 255.0,
        green: CGFloat(0xF2) / 255.0,
        blue: CGFloat(0xF4) / 255.0,
        alpha: 1.0
    )

    /// Resolves to the light or dark chrome color from the effective appearance.
    static let windowBackgroundColor = NSColor(name: "AppTheme.windowBackground") { appearance in
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? darkWindowBackgroundColor : lightWindowBackgroundColor
    }

    static let windowBackground = Color(nsColor: windowBackgroundColor)

    /// Print Label button fill (`#067dff`), locked to sRGB so color pickers
    /// match the authored hex (Display P3 / window blending won't remap it).
    static let printButtonNSColor = NSColor(
        srgbRed: 6.0 / 255.0,
        green: 125.0 / 255.0,
        blue: 255.0 / 255.0,
        alpha: 1.0
    )
    static let printButtonColor = Color(nsColor: printButtonNSColor)

    /// Opaque press state — slightly darkened `#067dff`, still fully opaque.
    static let printButtonPressedNSColor = NSColor(
        srgbRed: 5.0 / 255.0,
        green: 106.0 / 255.0,
        blue: 217.0 / 255.0,
        alpha: 1.0
    )
    static let printButtonPressedColor = Color(nsColor: printButtonPressedNSColor)

    /// Section titles like Recents, Text Style, Label, and Printer.
    static let sectionHeaderFont: Font = .title2.weight(.semibold)
}
#endif
