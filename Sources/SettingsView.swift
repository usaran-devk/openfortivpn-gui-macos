import ServiceManagement
import SwiftUI

/// Settings window for configuring VPN connection parameters.
struct SettingsView: View {
    @EnvironmentObject var vpnManager: VPNManager

    @State private var vpnHost: String = ""
    @State private var samlPort: String = ""
    @State private var setDNS: Bool = false
    @State private var peerDNS: Bool = true
    @State private var launchAtLogin: Bool = false
    @State private var hostError: String = ""
    @State private var portError: String = ""

    /// Whether the form has validation errors preventing save.
    private var hasErrors: Bool { !hostError.isEmpty || !portError.isEmpty }

    var body: some View {
        Form {
            Section {
                TextField(L10n.Settings.vpnHost, text: $vpnHost)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: vpnHost) { validateHost() }
                if !hostError.isEmpty {
                    Text(hostError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                TextField(L10n.Settings.samlPort, text: $samlPort)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: samlPort) { validatePort() }
                if !portError.isEmpty {
                    Text(portError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text(L10n.Settings.connectionSection)
            }

            Section {
                Toggle(L10n.Settings.setDNS, isOn: $setDNS)
                Toggle(L10n.Settings.peerDNS, isOn: $peerDNS)
            } header: {
                Text(L10n.Settings.dnsSection)
            } footer: {
                Text(L10n.Settings.dnsFooter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(L10n.Settings.launchAtLogin, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }
            } header: {
                Text(L10n.Settings.generalSection)
            }

            HStack {
                Spacer()
                Button(L10n.Settings.restoreDefaults) {
                    restoreDefaults()
                }
                Button(L10n.Settings.save) {
                    saveSettings()
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasErrors)
            }
        }
        .formStyle(.grouped)
        .frame(width: Constants.UI.settingsWidth, height: Constants.UI.settingsHeight)
        .onAppear { loadSettings() }
    }

    private func loadSettings() {
        vpnHost = vpnManager.settings.vpnHost
        samlPort = "\(vpnManager.settings.samlPort)"
        setDNS = vpnManager.settings.setDNS
        peerDNS = vpnManager.settings.peerDNS
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func saveSettings() {
        vpnManager.settings = VPNSettings(
            vpnHost: vpnHost,
            samlPort: Int(samlPort) ?? Constants.Defaults.samlPort,
            setDNS: setDNS,
            peerDNS: peerDNS
        )
        vpnManager.settings.save()
    }

    private func restoreDefaults() {
        let d = VPNSettings.default
        vpnHost = d.vpnHost
        samlPort = "\(d.samlPort)"
        setDNS = d.setDNS
        peerDNS = d.peerDNS
        hostError = ""
        portError = ""
    }

    /// Register or unregister the app as a login item via `SMAppService`.
    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("SettingsView: failed to \(enabled ? "register" : "unregister") login item: %@", error.localizedDescription)
            // Revert toggle to reflect actual state
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func validateHost() {
        let trimmed = vpnHost.trimmingCharacters(in: .whitespacesAndNewlines)
        hostError = trimmed.isEmpty ? L10n.Settings.hostRequired : ""
    }

    private func validatePort() {
        if let port = Int(samlPort),
           port >= Constants.Network.portMin,
           port <= Constants.Network.portMax {
            portError = ""
        } else {
            portError = L10n.Settings.invalidPort(Constants.Network.portMin, Constants.Network.portMax)
        }
    }
}
