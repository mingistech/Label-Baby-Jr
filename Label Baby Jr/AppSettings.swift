#if os(macOS)
import Combine
import SwiftUI

enum LaunchBehavior: String, CaseIterable, Identifiable, Codable {
    case recentLabelsPicker
    case newDocumentEditor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recentLabelsPicker: "Recent Labels"
        case .newDocumentEditor: "New Label Editor"
        }
    }

    var detail: String {
        switch self {
        case .recentLabelsPicker:
            "Show the recent labels picker when Label Baby Jr opens."
        case .newDocumentEditor:
            "Open a blank label editor when Label Baby Jr opens."
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private static let launchBehaviorKey = "launchBehavior"

    @Published var launchBehavior: LaunchBehavior {
        didSet {
            UserDefaults.standard.set(launchBehavior.rawValue, forKey: Self.launchBehaviorKey)
        }
    }

    private init() {
        if let rawValue = UserDefaults.standard.string(forKey: Self.launchBehaviorKey),
           let behavior = LaunchBehavior(rawValue: rawValue) {
            launchBehavior = behavior
        } else {
            launchBehavior = .recentLabelsPicker
        }
    }
}
#endif
