import Foundation

/// User-configurable VPN settings persisted via UserDefaults.
struct VPNSettings: Codable, Sendable, Equatable {
    var vpnHost: String
    var samlPort: Int
    var setDNS: Bool
    var peerDNS: Bool

    static let `default` = VPNSettings(
        vpnHost: Constants.Defaults.vpnHost,
        samlPort: Constants.Defaults.samlPort,
        setDNS: false,
        peerDNS: true
    )

    private static let storageKey = Constants.StorageKeys.vpnSettings

    /// Load settings from UserDefaults, falling back to defaults.
    static func load() -> VPNSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(VPNSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    /// Persist settings to UserDefaults.
    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            UserDefaults.standard.set(data, forKey: VPNSettings.storageKey)
        } catch {
            NSLog("VPNSettings.save: failed to encode settings: %@", error.localizedDescription)
        }
    }

    /// Resolved path to the openfortivpn binary.
    var openfortivpnPath: String {
        for path in Constants.Executables.openfortivpnSearchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return Constants.Executables.openfortivpnFallback
    }

    /// Build the openfortivpn command string for display/legacy use.
    var openfortivpnCommand: String {
        Constants.Process.openfortivpnName + " " + openfortivpnArguments.joined(separator: " ")
    }

    /// Arguments array for passing to `Process` (without the executable name).
    var openfortivpnArguments: [String] {
        let dns = setDNS ? "1" : "0"
        let peer = peerDNS ? "1" : "0"
        return [
            normalizedHost,
            "--set-dns=\(dns)",
            "--pppd-use-peerdns=\(peer)",
            "--saml-login=\(clampedPort)"
        ]
    }

    /// The SAML login URL for browser-based authentication.
    ///
    /// Returns `nil` if the host is empty or would produce an invalid URL.
    var samlURL: URL? {
        let host = normalizedHost
        guard !host.isEmpty else { return nil }
        return URL(string: "https://\(host)\(Constants.Network.samlLoginPath)")
    }

    /// The VPN host with whitespace trimmed and any scheme prefix removed.
    var normalizedHost: String {
        var host = vpnHost.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in Constants.Network.schemePrefixes {
            if host.lowercased().hasPrefix(prefix) {
                host = String(host.dropFirst(prefix.count))
                break
            }
        }
        return host
    }

    /// The SAML port clamped to the valid TCP port range.
    var clampedPort: Int {
        min(max(samlPort, Constants.Network.portMin), Constants.Network.portMax)
    }
}
