import SwiftUI

/// Main entry point for the OpenFortiVPN GUI application.
@main
struct OpenFortiVPNApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.vpnManager)
        }
    }
}
