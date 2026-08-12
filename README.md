# Label Baby Jr

A native macOS app for designing and printing rich-text labels on DYMO label printers.

Label Baby Jr is a lightweight label editor built with SwiftUI and AppKit. It's purpose-built for a single label size (89×28mm, DYMO's standard) with a focused set of rich text formatting tools, so you can go from a blank label to a printed one in seconds.

<img src="https://raw.githubusercontent.com/mingistech/Label-Baby-Jr/f8a7b61f6ee26782c6d3178eefce33899fc8b20a/docs/preview-autofit.png" alt="Label Baby Jr editor screenshot" width="532">

## Features

- **Single-window workspace** — Recents sidebar and label editor share one window
- **Rich text editing** — bold, italic, underline, font size, and left/center/right alignment
- **Auto fit** — text starts large and shrinks as you type so it always fits the label; turn it off to size by hand
- **WYSIWYG label preview** — an enlarged, print-accurate editor view of the 89×28mm die-cut label
- **DYMO printing** — printer picker (filtered to DYMO printers) with copies on the same row
- **Documents** — save and open `.labelbabyjr` files (JSON); File → New / Open / Save / Save As
- **Appearance** — Light, Dark, or Follow System in Settings

## Requirements

- macOS 15 (Sequoia) or later to run
- Xcode 26 or later to build (the project uses some newer Swift language features)

## Building

1. Clone the repo and open `Label Baby Jr.xcodeproj` in Xcode.
2. Select the **Label Baby Jr** scheme with the **My Mac** run destination.
3. Build and run (`⌘R`).

To build a distributable, signed, and notarized copy for sharing outside the Mac App Store, archive via **Product → Archive**, then use Xcode's Organizer to distribute with **Direct Distribution** (Developer ID signing + notarization).

## The `.labelbabyjr` file format

Labels are saved as JSON documents describing the label size and an ordered list of text "runs," where each run carries its own font size, bold/italic/underline flags, and alignment:

```json
{
  "formatVersion": 1,
  "labelSize": { "widthMM": 89, "heightMM": 28 },
  "autoSize": true,
  "maxFontSize": 52,
  "runs": [
    { "text": "Hello", "fontSize": 14, "bold": true, "italic": false, "underline": false, "alignment": "center" }
  ]
}
```

## Project structure

| File | Responsibility |
| --- | --- |
| `LabelBabyJrApp.swift` | App entry point; single editor window and File menu commands |
| `LabelWorkspace.swift` | Open / save / new document session and dirty-state prompts |
| `ContentView.swift` | Editor chrome; binds the workspace to `LabelEditorController` |
| `RecentLabelsSidebar.swift` | Scrollable recent-label previews (click to select, double-click to open) |
| `EditableLabelView.swift` | The `NSTextView`-backed rich text editor and its SwiftUI wrapper |
| `LabelEditorController.swift` | Editor state (style, selection) and document change notifications |
| `LabelBabyJrDocument.swift` / `LabelBabyJrFileFormat.swift` | Document type and the `.labelbabyjr` file format |
| `PrinterService.swift` / `LabelPrintView.swift` | DYMO printer discovery and print rendering |
| `LabelStockPreview.swift` | Die-cut label silhouette used in the editor and thumbnails |
| `SettingsView.swift` / `AppSettings.swift` | Appearance and other preferences |
| `LabelTypography.swift` | Shared label size, font, and margin constants |
| `LabelAutoFitSizer.swift` | Binary-search sizer that finds the largest whole-point font that still fits |

## License

Released under the [MIT License](LICENSE).
