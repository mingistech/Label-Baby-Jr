import SwiftUI

#if os(macOS)
import AppKit

private struct EditorColumnHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 480
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentView: View {
    private let editorWidth: CGFloat = 440

    @ObservedObject private var settings = AppSettings.shared
    @EnvironmentObject private var recentLabels: RecentLabelsStore
    @EnvironmentObject private var workspace: LabelWorkspace
    @StateObject private var printerService = PrinterService()
    @StateObject private var editor = LabelEditorController()
    @State private var numberOfCopies = 1
    @State private var editorColumnHeight: CGFloat = 480
    @State private var loadedEpoch: Int = -1

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.windowBackground
                .ignoresSafeArea()

            HStack(alignment: .top, spacing: 18) {
                RecentLabelsSidebar(
                    openURL: workspace.fileURL,
                    height: editorColumnHeight
                ) { item in
                    workspace.openLabel(item)
                }

                editorColumn
                    .frame(width: editorWidth, alignment: .topLeading)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: EditorColumnHeightKey.self,
                                value: proxy.size.height
                            )
                        }
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
            .padding(.top, 20)
            .onPreferenceChange(EditorColumnHeightKey.self) { height in
                if height > 0 {
                    editorColumnHeight = height
                }
            }

            HStack {
                Spacer()
                SettingsToolbarButton()
            }
            .padding(.top, 10)
            .padding(.trailing, 16)
        }
        // Re-evaluate chrome when Appearance changes in Settings.
        .preferredColorScheme(colorSchemeOverride)
        .fixedSize(horizontal: true, vertical: true)
        .background(WindowFrameConfigurator(promptsToSaveOnClose: true))
        .onAppear {
            attachEditorIfNeeded()
            recentLabels.refresh()
        }
        .onChange(of: workspace.documentEpoch) { _, _ in
            reloadEditorFromWorkspace()
        }
    }

    private var colorSchemeOverride: ColorScheme? {
        switch settings.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    private var editorColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                textStyleSection
                alignmentSection
                labelSection
                printerSection
            }

            printButton
                .padding(.top, 40)
        }
    }

    private func attachEditorIfNeeded() {
        guard loadedEpoch != workspace.documentEpoch else { return }
        reloadEditorFromWorkspace()
    }

    private func reloadEditorFromWorkspace() {
        editor.load(from: workspace.document.file)
        editor.onDocumentContentChanged = {
            workspace.noteEditorContentChanged(editor.makeFileContent())
            if let url = workspace.fileURL {
                recentLabels.recordDocument(at: url)
            }
        }
        workspace.flushEditorContent = {
            editor.flushPendingDocumentChanges()
        }
        loadedEpoch = workspace.documentEpoch
    }

    private var textStyleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text Style")
                .font(AppTheme.sectionHeaderFont)

            HStack(spacing: 12) {
                HStack(spacing: 6) {
                    // An adjacent Stepper claims all the width it is offered, so
                    // these labels need fixedSize or they collapse to one
                    // character per line.
                    Text("Size")
                        .fixedSize()
                    Stepper(value: Binding(
                        get: { editor.isAutoSizeEnabled ? editor.fittedFontSize : editor.selectionFontSize },
                        set: { editor.applyFontSize($0) }
                    ), in: LabelTypography.minimumFontSize ... LabelTypography.maximumFontSize, step: 1) {
                        Text("\(formatted(editor.isAutoSizeEnabled ? editor.fittedFontSize : editor.selectionFontSize)) pt")
                            .monospacedDigit()
                            .fixedSize()
                            .frame(width: 40, alignment: .leading)
                    }
                }
                .fixedSize()
                .help("Sizes the selected text, or the whole label when nothing is selected. Turns off Auto fit.")

                Toggle("Bold", isOn: Binding(
                    get: { editor.isBold },
                    set: { editor.setBold($0) }
                ))
                Toggle("Italic", isOn: Binding(
                    get: { editor.isItalic },
                    set: { editor.setItalic($0) }
                ))
                Toggle("Underline", isOn: Binding(
                    get: { editor.isUnderlined },
                    set: { editor.setUnderline($0) }
                ))
                Toggle("Auto fit", isOn: Binding(
                    get: { editor.isAutoSizeEnabled },
                    set: { editor.setAutoSizeEnabled($0) }
                ))

                Spacer(minLength: 0)
            }
            .toggleStyle(.checkbox)
        }
    }

    private func formatted(_ size: CGFloat) -> String {
        size == size.rounded() ? "\(Int(size))" : String(format: "%.1f", size)
    }

    private var alignmentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Alignment")
                .font(AppTheme.sectionHeaderFont)

            Picker("Alignment", selection: Binding(
                get: { editor.alignment },
                set: { editor.applyAlignment($0) }
            )) {
                ForEach(LabelTextAlignment.allCases) { alignment in
                    Text(alignment.title).tag(alignment)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
    }

    private var labelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Label")
                .font(AppTheme.sectionHeaderFont)

            HStack {
                Spacer(minLength: 0)
                EditableLabelView(controller: editor)
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                if editor.isTextOverflowing {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(overflowMessage)
                        .fixedSize(horizontal: false, vertical: true)
                } else if editor.isAutoSizeEnabled {
                    Text("Auto fit to \(formatted(editor.fittedFontSize)) pt.")
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Sized by hand at \(formatted(editor.fittedFontSize)) pt. Auto fit is off.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var overflowMessage: String {
        if editor.isAutoSizeEnabled {
            return "Too long to fit at \(Int(LabelTypography.minimumFontSize)) pt — shorten the text or remove a line."
        }
        return "Too big to fit — reduce the size or turn Auto fit back on."
    }

    private var printerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Printer")
                .font(AppTheme.sectionHeaderFont)

            HStack(spacing: 8) {
                if printerService.availablePrinters.isEmpty {
                    Text("No DYMO printers found. Add your DYMO printer in System Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Picker("Printer", selection: $printerService.selectedPrinter) {
                        ForEach(printerService.availablePrinters, id: \.self) { printer in
                            Text(printer).tag(printer)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }

                HStack(spacing: 4) {
                    Text("Copies")
                        .fixedSize()
                    Text("\(numberOfCopies)")
                        .monospacedDigit()
                        .fixedSize()
                    Stepper("Copies", value: $numberOfCopies, in: 1 ... 99)
                        .labelsHidden()
                }

                Spacer(minLength: 0)

                Button("Refresh") {
                    printerService.refreshPrinters()
                }
                .padding(.trailing, 12)
            }
        }
    }

    @ViewBuilder
    private var printButton: some View {
        let isEnabled = editor.canPrint && !printerService.selectedPrinter.isEmpty

        Button {
            guard isEnabled else { return }
            guard let attributedString = editor.attributedStringForPrinting() else { return }
            printerService.print(attributedString: attributedString, copies: numberOfCopies)
        } label: {
            Text("Print Label")
        }
        .buttonStyle(PrintLabelButtonStyle(isEnabled: isEnabled))
        // Avoid `.disabled` / `.opacity` — both fade the fill and let the window
        // tint show through, shifting `#067dff` toward a muddy blue.
        .allowsHitTesting(isEnabled)
        .frame(maxWidth: .infinity)
    }
}

/// Draws an opaque sRGB fill so color pickers read `#067dff`.
private struct PrintLabelButtonStyle: ButtonStyle {
    var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title.weight(.semibold))
            .foregroundStyle(Color(nsColor: .white))
            .tint(.white)
            .frame(width: 320)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fillColor(pressed: configuration.isPressed))
            )
    }

    private func fillColor(pressed: Bool) -> Color {
        // Keep `#067dff` even when inactive — a separate “disabled blue” was
        // what color pickers were reading as `#466ea0`.
        if isEnabled && pressed {
            return AppTheme.printButtonPressedColor
        }
        return AppTheme.printButtonColor
    }
}

#Preview {
    ContentView()
        .environmentObject(RecentLabelsStore.shared)
        .environmentObject(LabelWorkspace.shared)
}
#endif
