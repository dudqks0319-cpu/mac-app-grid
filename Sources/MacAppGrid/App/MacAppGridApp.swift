import SwiftUI

@main
struct MacAppGridApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(SettingsStore.shared)
        }
    }
}
