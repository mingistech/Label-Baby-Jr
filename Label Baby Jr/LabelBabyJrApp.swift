#if os(macOS)
import AppKit
#endif
import SwiftUI

@main
struct LabelBabyJrApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(LabelBabyJrAppDelegate.self) private var appDelegate
    @ObservedObject private var workspace = LabelWorkspace.shared
    #if !APP_STORE
    @ObservedObject private var updateChecker = UpdateChecker.shared
    #endif
    #endif

    var body: some Scene {
        #if os(macOS)
        WindowGroup("Label Baby Jr") {
            ContentView()
                .environmentObject(RecentLabelsStore.shared)
                .environmentObject(workspace)
                .onAppear {
                    #if !APP_STORE
                    Task {
                        await updateChecker.checkForUpdatesIfDue()
                    }
                    #endif
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            #if !APP_STORE
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    Task {
                        await updateChecker.checkForUpdates()
                    }
                }
                .disabled(updateChecker.isChecking)
            }
            #endif

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

            CommandGroup(after: .help) {
                Button("Label Baby Jr Support") {
                    NSWorkspace.shared.open(AppLinks.support)
                }

                Button("Privacy Policy") {
                    NSWorkspace.shared.open(AppLinks.privacyPolicy)
                }
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

#if os(macOS)
private enum AppLinks {
    static let support = URL(string: "https://github.com/mingistech/Label-Baby-Jr/issues")!
    static let privacyPolicy = URL(string: "https://github.com/mingistech/Label-Baby-Jr/blob/main/PRIVACY.md")!
}
#endif
