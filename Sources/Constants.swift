import Foundation

/// Centralized constants for the application.
///
/// Groups all hard-coded strings and magic numbers so they can be
/// maintained in a single place (AGENTS.md Key Guideline #8).
enum Constants {

    // MARK: - Executable Paths

    /// Paths to system and third-party executables.
    enum Executables {
        static let sudo = "/usr/bin/sudo"
        static let kill = "/usr/bin/kill"
        static let pgrep = "/usr/bin/pgrep"
        static let osascript = "/usr/bin/osascript"
        /// Candidate paths for the openfortivpn binary (Homebrew locations).
        static let openfortivpnSearchPaths = [
            "/opt/homebrew/bin/openfortivpn",
            "/usr/local/bin/openfortivpn",
        ]
        /// Fallback path when none of the search paths contain an executable.
        static let openfortivpnFallback = "/usr/local/bin/openfortivpn"
    }

    // MARK: - Process

    /// Process names, arguments, and signals used for process management.
    enum Process {
        static let openfortivpnName = "openfortivpn"
        /// The `kill` command name passed to sudo.
        static let killCommand = "kill"
        /// The `--version` flag used to test sudoers access.
        static let versionFlag = "--version"
        /// SIGTERM signal number for graceful termination.
        static let sigterm: Int32 = 15
        /// SIGKILL signal number for forceful termination.
        static let sigkill: Int32 = 9
    }

    // MARK: - Sudoers

    /// Configuration for the sudoers drop-in rule.
    enum Sudoers {
        static let filePath = "/etc/sudoers.d/openfortivpn-gui"
    }

    // MARK: - Log Detection

    /// Strings matched against openfortivpn stdout/stderr to detect state changes.
    enum LogPatterns {
        /// Emitted when the VPN tunnel is fully established.
        static let tunnelUp = "Tunnel is up and running"
        /// Alternative line indicating the tunnel is connected.
        static let connectedToGateway = "Connected to gateway"
        /// Emitted when the SAML HTTP proxy is bound and accepting connections.
        static let samlProxyListening = "Listening for SAML login on port"
    }

    // MARK: - Networking

    enum Network {
        static let localhost = "127.0.0.1"
        /// Path appended to the VPN host to initiate SAML authentication.
        static let samlLoginPath = "/remote/saml/start?redirect=1"
        /// Valid TCP port range.
        static let portMin = 1
        static let portMax = 65535
        /// URL scheme prefixes to strip from the VPN host input.
        static let schemePrefixes = ["https://", "http://"]
    }

    // MARK: - Defaults

    /// Default values for settings and configuration.
    enum Defaults {
        static let vpnHost = ""
        static let samlPort = 8020
    }

    // MARK: - UserDefaults Keys

    enum StorageKeys {
        static let vpnSettings = "vpnSettings"
    }

    // MARK: - UI

    enum UI {
        static let appDisplayName = "OpenFortiVPN"
        static let popoverWidth: CGFloat = 320
        static let popoverHeight: CGFloat = 380
        static let settingsWidth: CGFloat = 420
        static let settingsHeight: CGFloat = 360
        /// Maximum number of log lines retained in the buffer.
        static let logBufferLimit = 500
        static let logDateFormat = "HH:mm:ss"
        /// Standard horizontal padding for popover sections.
        static let sectionPaddingH: CGFloat = 16
        /// Standard vertical padding for popover sections.
        static let sectionPaddingV: CGFloat = 12
        /// Compact vertical padding for smaller sections.
        static let compactPaddingV: CGFloat = 8
        /// Diameter of the status indicator circle.
        static let statusIndicatorSize: CGFloat = 10
    }

    // MARK: - SF Symbols

    /// SF Symbol names used for the menu bar icon and UI controls.
    enum Symbols {
        static let shieldDefault = "lock.shield"
        static let shieldConnected = "lock.shield.fill"
        static let shieldSAML = "person.badge.shield.checkmark"
        static let shieldError = "exclamationmark.shield"
        static let appIcon = "shield.checkered"
        static let trash = "trash"
        static let settings = "gearshape"
    }
}
