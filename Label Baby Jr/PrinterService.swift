#if os(macOS)
import AppKit
import Combine

@MainActor
final class PrinterService: ObservableObject {
    @Published var availablePrinters: [String] = []
    @Published var selectedPrinter: String = ""

    init() {
        refreshPrinters()
    }

    func refreshPrinters() {
        availablePrinters = NSPrinter.printerNames
            .filter { $0.localizedCaseInsensitiveContains("dymo") }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        if selectedPrinter.isEmpty || !availablePrinters.contains(selectedPrinter) {
            selectedPrinter = availablePrinters.first ?? ""
        }
    }

    func print(attributedString: NSAttributedString, copies: Int = 1) {
        guard !selectedPrinter.isEmpty else { return }
        guard let printer = NSPrinter(name: selectedPrinter) else { return }

        let printInfo = NSPrintInfo()
        printInfo.printer = printer
        printInfo.dictionary()[NSPrintInfo.AttributeKey.copies] = NSNumber(value: max(1, copies))
        printInfo.paperSize = NSSize(width: LabelTypography.widthPoints, height: LabelTypography.heightPoints)
        printInfo.topMargin = 0
        printInfo.bottomMargin = 0
        printInfo.leftMargin = 0
        printInfo.rightMargin = 0
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        printInfo.jobDisposition = .spool

        let printView = LabelPrintView(attributedString: attributedString)
        let printOperation = NSPrintOperation(view: printView, printInfo: printInfo)
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = true
        printOperation.run()
    }
}
#endif
