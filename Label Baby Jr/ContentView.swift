import SwiftUI

#if os(macOS)
import AppKit

struct ContentView: View {
    private let windowWidth: CGFloat = 420

    @Binding var document: LabelBabyJrDocument
    var fileURL: URL?
    @EnvironmentObject private var recentLabels: RecentLabelsStore
    @StateObject private var printerService = PrinterService()
    @StateObject private var editor = LabelEditorController()
    @State private var numberOfCopies = 1
    @State private var hasLoadedDocument = false

    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.windowBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                textStyleSection
                alignmentSection
                labelSection
                printerSection
                printButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
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
            guard !hasLoadedDocument else { return }
            editor.load(from: document.file)
            editor.onDocumentContentChanged = {
                document.file = editor.makeFileContent()
                // SwiftUI's `configuration.fileURL` doesn't reliably update this
                // already-rendered view once a brand-new document is saved for
                // the first time, so ask AppKit directly for the live URL
                // instead of relying on the (possibly stale) `fileURL` property.
                if let liveURL = NSDocumentController.shared.currentDocument?.fileURL {
                    recentLabels.recordDocument(at: liveURL)
                }
            }
            hasLoadedDocument = true
            if let fileURL {
                recentLabels.recordDocument(at: fileURL)
            }
        }
        .onChange(of: fileURL) { _, url in
            if let url {
                recentLabels.recordDocument(at: url)
            }
        }
    }

    private var textStyleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Text Style")
                .font(.headline)

            HStack(spacing: 12) {
                Text("Size")
                Stepper(value: Binding(
                    get: { editor.fontSize },
                    set: { editor.applyFontSize($0) }
                ), in: 6 ... 36, step: 1) {
                    Text("\(Int(editor.fontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }

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

                Spacer(minLength: 0)
            }
            .toggleStyle(.checkbox)
        }
    }

    private var alignmentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Alignment")
                .font(.headline)

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
                .font(.headline)

            HStack {
                Spacer(minLength: 0)
                EditableLabelView(controller: editor)
                Spacer(minLength: 0)
            }
        }
    }

    private var printerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Printer")
                .font(.headline)

            HStack(spacing: 8) {
                if printerService.availablePrinters.isEmpty {
                    Text("No DYMO printers found. Add your DYMO printer in System Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Picker("Printer", selection: $printerService.selectedPrinter) {
                        ForEach(printerService.availablePrinters, id: \.self) { printer in
                            Text(printer).tag(printer)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Refresh") {
                    printerService.refreshPrinters()
                }
            }

            HStack(spacing: 6) {
                Text("Copies")
                Stepper(value: $numberOfCopies, in: 1 ... 99) {
                    Text("\(numberOfCopies)")
                        .monospacedDigit()
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }

    private var printButton: some View {
        Button("Print Label") {
            guard let attributedString = editor.attributedStringForPrinting() else { return }
            printerService.print(attributedString: attributedString, copies: numberOfCopies)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!editor.canPrint || printerService.selectedPrinter.isEmpty)
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }
}

#Preview {
    ContentView(document: .constant(LabelBabyJrDocument()), fileURL: nil)
        .environmentObject(RecentLabelsStore.shared)
}
#endif
