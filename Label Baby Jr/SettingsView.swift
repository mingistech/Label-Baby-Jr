#if os(macOS)
import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.title2.weight(.bold))

            Form {
                Section {
                    Picker("At launch open", selection: $settings.launchBehavior) {
                        ForEach(LaunchBehavior.allCases) { behavior in
                            Text(behavior.title).tag(behavior)
                        }
                    }
                    .pickerStyle(.radioGroup)

                    Text(settings.launchBehavior.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } footer: {
                    Text("This preference takes effect the next time you open Label Baby Jr.")
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 440, height: 240)
        .padding(20)
        .background(SettingsWindowConfigurator())
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
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

    private func configureWindow(for view: NSView) {
        guard let window = view.window else { return }
        window.title = ""
        window.titleVisibility = .hidden
    }
}

#Preview {
    SettingsView()
}
#endif
