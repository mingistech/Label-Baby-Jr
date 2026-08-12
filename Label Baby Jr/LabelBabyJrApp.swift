import SwiftUI

@main
struct LabelBabyJrApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(LabelBabyJrAppDelegate.self) private var appDelegate
    @ObservedObject private var workspace = LabelWorkspace.shared
    #endif

    var body: some Scene {
        #if os(macOS)
        WindowGroup("Label Baby Jr") {
            ContentView()
                .environmentObject(RecentLabelsStore.shared)
                .environmentObject(workspace)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Label") {
                    workspace.newLabel()
                }
                .keyboardShortcut("n")

                Button("Open…") {
                    workspace.openInteractive()
                }
                .keyboardShortcut("o")
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    workspace.save()
                }
                .keyboardShortcut("s")

                Button("Save As…") {
                    workspace.saveAs()
                }
                .keyboardShortcut("S")
            }
        }

        Settings {
            SettingsView()
        }
        #else
        WindowGroup {
            Text("Label Baby Jr is available on macOS.")
                .padding()
        }
        #endif
    }
}
