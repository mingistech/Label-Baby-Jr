import SwiftUI

@main
struct LabelBabyJrApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(LabelBabyJrAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        #if os(macOS)
        let launchBehavior = AppSettings.shared.launchBehavior

        WindowGroup("Label Baby Jr", id: "home") {
            HomeView()
                .environmentObject(RecentLabelsStore.shared)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(launchBehavior == .recentLabelsPicker ? .presented : .suppressed)

        DocumentGroup(newDocument: LabelBabyJrDocument()) { configuration in
            ContentView(
                document: configuration.$document,
                fileURL: configuration.fileURL
            )
            .environmentObject(RecentLabelsStore.shared)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

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
