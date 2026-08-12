#if os(macOS)
import AppKit
import Combine
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum Appearance: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: return "Follow System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }

        var nsAppearance: NSAppearance? {
            switch self {
            case .system: return nil
            case .light: return NSAppearance(named: .aqua)
            case .dark: return NSAppearance(named: .darkAqua)
            }
        }
    }

    private enum Keys {
        static let appearance = "settings.appearance"
    }

    @Published var appearance: Appearance {
        didSet {
            guard oldValue != appearance else { return }
            UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance)
            applyAppearance()
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Keys.appearance),
           let stored = Appearance(rawValue: raw) {
            appearance = stored
        } else {
            appearance = .system
        }
    }

    func applyAppearance() {
        NSApp.appearance = appearance.nsAppearance
    }
}
#endif
