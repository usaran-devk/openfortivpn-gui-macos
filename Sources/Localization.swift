import Foundation

/// Provides localized strings for the application.
/// Supports English (en) and German (de).
enum L10n {
    /// The current locale identifier (e.g. "en", "de").
    static var locale: String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("de") { return "de" }
        return "en"
    }

    // MARK: - VPN States

    enum State {
        static var disconnected: String {
            locale == "de" ? "Getrennt" : "Disconnected"
        }
        static var connecting: String {
            locale == "de" ? "Verbinde\u{2026}" : "Connecting\u{2026}"
        }
        static var waitingForSAML: String {
            locale == "de" ? "Warte auf SAML-Anmeldung\u{2026}" : "Waiting for SAML Login\u{2026}"
        }
        static var connected: String {
            locale == "de" ? "Verbunden" : "Connected"
        }
        static var disconnecting: String {
            locale == "de" ? "Trenne\u{2026}" : "Disconnecting\u{2026}"
        }
        static var error: String {
            locale == "de" ? "Fehler" : "Error"
        }
    }

    // MARK: - Actions

    enum Action {
        static var connect: String {
            locale == "de" ? "Verbinden" : "Connect"
        }
        static var disconnect: String {
            locale == "de" ? "Trennen" : "Disconnect"
        }
        static var quit: String {
            locale == "de" ? "Beenden" : "Quit"
        }
    }

    // MARK: - Menu Bar

    enum MenuBar {
        static var label: String {
            locale == "de" ? "VPN-Status" : "VPN Status"
        }
    }

    // MARK: - Log

    enum Log {
        static var title: String {
            locale == "de" ? "Protokoll" : "Log"
        }
        static func starting(_ args: String) -> String {
            locale == "de" ? "Starte: openfortivpn \(args)" : "Starting: openfortivpn \(args)"
        }
        static var disconnecting: String {
            locale == "de" ? "Trenne\u{2026}" : "Disconnecting\u{2026}"
        }
        static var disconnected: String {
            locale == "de" ? "Getrennt." : "Disconnected."
        }
        static func openingSAML(_ url: String) -> String {
            locale == "de" ? "\u{00D6}ffne SAML-Anmeldung: \(url)" : "Opening SAML login: \(url)"
        }
        static func unexpectedTermination(_ exitCode: Int32) -> String {
            locale == "de"
                ? "Verbindung unerwartet beendet (Exit-Code: \(exitCode))."
                : "Connection terminated unexpectedly (exit code: \(exitCode))."
        }
        static func processExited(_ exitCode: Int32) -> String {
            locale == "de"
                ? "Prozess mit Code \(exitCode) beendet."
                : "Process exited with code \(exitCode)."
        }
        static func processStartFailed(_ error: String) -> String {
            locale == "de"
                ? "Prozess konnte nicht gestartet werden: \(error)"
                : "Failed to start process: \(error)"
        }
        static func probingSAMLProxy(_ port: Int) -> String {
            locale == "de"
                ? "Pr\u{00FC}fe SAML-Proxy auf \(Constants.Network.localhost):\(port)\u{2026}"
                : "Probing SAML proxy at \(Constants.Network.localhost):\(port)\u{2026}"
        }
        static var samlProxyNotReady: String {
            locale == "de"
                ? "SAML-Proxy nicht erreichbar, \u{00F6}ffne Browser trotzdem."
                : "SAML proxy not reachable, opening browser anyway."
        }
    }

    // MARK: - Errors

    enum Error {
        static var connectionFailed: String {
            locale == "de" ? "Verbindung fehlgeschlagen" : "Connection failed"
        }
        static var sudoersNotConfigured: String {
            locale == "de"
                ? "Sudoers-Regel nicht installiert. Bitte 'make install-sudoers' ausf\u{00FC}hren."
                : "Sudoers rule not installed. Please run 'make install-sudoers'."
        }
        static var vpnHostEmpty: String {
            locale == "de"
                ? "VPN-Host nicht konfiguriert. Bitte in den Einstellungen angeben."
                : "VPN host not configured. Please set it in Settings."
        }
    }

    // MARK: - Sudoers Alert

    enum Sudoers {
        static var alertTitle: String {
            locale == "de"
                ? "Sudoers-Regel erforderlich"
                : "Sudoers Rule Required"
        }
        static var alertMessage: String {
            locale == "de"
                ? "Die Sudoers-Regel ist nicht installiert. openfortivpn ben\u{00F6}tigt Root-Rechte ohne Passwortabfrage. M\u{00F6}chten Sie die Regel jetzt installieren?"
                : "The sudoers rule is not installed. openfortivpn requires root privileges without a password prompt. Would you like to install the rule now?"
        }
        static var install: String {
            locale == "de" ? "Installieren" : "Install"
        }
        static var cancel: String {
            locale == "de" ? "Abbrechen" : "Cancel"
        }
        static var installSuccess: String {
            locale == "de"
                ? "Sudoers-Regel erfolgreich installiert."
                : "Sudoers rule installed successfully."
        }
        static var installFailed: String {
            locale == "de"
                ? "Sudoers-Regel konnte nicht installiert werden."
                : "Failed to install sudoers rule."
        }
    }

    // MARK: - Settings

    enum Settings {
        static var connectionSection: String {
            locale == "de" ? "Verbindung" : "Connection"
        }
        static var dnsSection: String { "DNS" }
        static var vpnHost: String { "VPN-Host" }
        static var samlPort: String { "SAML-Port" }
        static var setDNS: String {
            locale == "de" ? "DNS setzen (--set-dns)" : "Set DNS (--set-dns)"
        }
        static var peerDNS: String {
            locale == "de" ? "Peer-DNS verwenden (--pppd-use-peerdns)" : "Use Peer DNS (--pppd-use-peerdns)"
        }
        static var dnsFooter: String {
            locale == "de"
                ? "Unter macOS \u{201E}DNS setzen\u{201C} deaktivieren und \u{201E}Peer-DNS verwenden\u{201C} aktivieren, um korrekte DNS-Aufl\u{00F6}sung sicherzustellen."
                : "On macOS, disable \u{2018}Set DNS\u{2019} and enable \u{2018}Use Peer DNS\u{2019} for proper DNS resolution."
        }
        static var save: String {
            locale == "de" ? "Speichern" : "Save"
        }
        static var restoreDefaults: String {
            locale == "de" ? "Standardwerte" : "Restore Defaults"
        }
        static var title: String {
            locale == "de" ? "Einstellungen" : "Settings"
        }
        static func invalidPort(_ min: Int, _ max: Int) -> String {
            locale == "de"
                ? "Ung\u{00FC}ltiger Port. Erlaubt: \(min)\u{2013}\(max)."
                : "Invalid port. Allowed: \(min)\u{2013}\(max)."
        }
        static var hostRequired: String {
            locale == "de" ? "VPN-Host ist erforderlich." : "VPN host is required."
        }
        static var generalSection: String {
            locale == "de" ? "Allgemein" : "General"
        }
        static var launchAtLogin: String {
            locale == "de" ? "Bei Anmeldung starten" : "Launch at Login"
        }
    }
}
