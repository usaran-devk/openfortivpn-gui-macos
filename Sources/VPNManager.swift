import Foundation
import AppKit

/// A single log entry with a stable, monotonically increasing ID for SwiftUI list identity.
struct LogEntry: Identifiable {
    let id: Int
    let text: String
}

/// Manages the lifecycle of the openfortivpn VPN process.
///
/// Provides connect/disconnect functionality, monitors the process output
/// to detect state changes, and handles the SAML browser authentication flow.
@MainActor
final class VPNManager: ObservableObject {
    @Published var state: VPNState = .disconnected
    @Published var settings: VPNSettings = VPNSettings.load()
    @Published private(set) var log: [LogEntry] = []

    /// Set to `true` when a connect attempt fails due to missing sudoers rule.
    /// The UI observes this to present the install-sudoers alert.
    @Published var showSudoersAlert = false

    /// Monotonically increasing log line ID for stable SwiftUI list identity.
    private(set) var logNextID: Int = 0

    /// The `sudo openfortivpn` process we hold directly.
    private var vpnProcess: Process?
    private var connectedSince: Date?

    /// Whether the SAML browser has been opened for the current connection attempt.
    private var samlBrowserOpened = false

    /// The date/time when the current connection was established.
    var connectionDate: Date? { connectedSince }

    // MARK: - Public API

    /// Connect to the VPN using the current settings.
    ///
    /// Launches `sudo openfortivpn` directly (sudoers NOPASSWD rule required),
    /// monitors process output for SAML proxy readiness (the exact log line
    /// `"Listening for SAML login on port <N>"`), then opens the browser
    /// for authentication. A fallback timer with TCP probe ensures the browser
    /// opens even if the log line format changes in future openfortivpn versions.
    func connect() {
        guard state == .disconnected || isErrorState else { return }

        // Validate that a VPN host has been configured
        if settings.normalizedHost.isEmpty {
            appendLog(L10n.Error.vpnHostEmpty)
            state = .error(L10n.Error.vpnHostEmpty)
            return
        }

        // Check sudoers before attempting to connect (AGENTS.md Functional #3)
        if !PrivilegedExecution.isSudoersConfigured() {
            appendLog(L10n.Error.sudoersNotConfigured)
            state = .error(L10n.Error.sudoersNotConfigured)
            showSudoersAlert = true
            return
        }

        state = .connecting
        log = []
        logNextID = 0
        connectedSince = nil
        samlBrowserOpened = false
        settings.save()

        let args = settings.openfortivpnArguments
        appendLog(L10n.Log.starting(args.joined(separator: " ")))

        let execPath = settings.openfortivpnPath

        vpnProcess = PrivilegedExecution.run(
            executable: execPath,
            arguments: args,
            outputHandler: { [weak self] line in
                Task { @MainActor [weak self] in
                    self?.handleOutput(line)
                }
            },
            terminationHandler: { [weak self] status in
                Task { @MainActor [weak self] in
                    self?.handleTermination(status: status)
                }
            }
        )

        // Fallback: if log-based detection didn't fire, probe the port and open browser
        let samlPort = settings.samlPort
        Task {
            try? await Task.sleep(for: .seconds(5))
            guard !self.samlBrowserOpened,
                  self.state == .connecting || self.state == .waitingForSAML else { return }
            self.state = .waitingForSAML
            self.appendLog(L10n.Log.probingSAMLProxy(samlPort))
            let reachable = await Self.probeSAMLProxy(port: samlPort)
            if !reachable {
                self.appendLog(L10n.Log.samlProxyNotReady)
            }
            self.openSAMLLogin()
        }
    }

    /// Disconnect from the VPN, reliably terminating the openfortivpn process.
    ///
    /// Uses a 3-stage approach: (1) SIGTERM the sudo wrapper, (2) `sudo kill -15`
    /// on discovered openfortivpn PIDs (off main thread), (3) SIGKILL after timeout.
    func disconnect() {
        guard state.isActive else { return }

        state = .disconnecting
        appendLog(L10n.Log.disconnecting)

        // Step 1: Terminate the sudo process we hold (sends SIGTERM to process group)
        if let process = vpnProcess, process.isRunning {
            process.terminate()
        }

        // Step 2: Find and kill openfortivpn PIDs off the main thread to avoid blocking UI
        let capturedProcess = vpnProcess
        Task.detached {
            PrivilegedExecution.killOpenfortivpnProcesses(signal: Constants.Process.sigterm)

            // Step 3: After a timeout, force-kill anything remaining
            try? await Task.sleep(for: .seconds(3))

            await MainActor.run {
                guard self.state == .disconnecting else { return }
            }

            // SIGKILL the sudo process if still alive
            if let process = capturedProcess, process.isRunning {
                process.interrupt()
            }

            // SIGKILL any remaining openfortivpn processes
            PrivilegedExecution.killOpenfortivpnProcesses(signal: Constants.Process.sigkill)

            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                if self.state == .disconnecting {
                    self.vpnProcess = nil
                    self.state = .disconnected
                    self.connectedSince = nil
                    self.appendLog(L10n.Log.disconnected)
                }
            }
        }
    }

    /// Synchronously kill any openfortivpn processes. Called during app termination.
    func terminateImmediately() {
        if let process = vpnProcess, process.isRunning {
            process.terminate()
        }
        PrivilegedExecution.killOpenfortivpnProcesses(signal: Constants.Process.sigterm)
        vpnProcess = nil
    }

    /// Clear the log buffer.
    func clearLog() {
        log = []
        logNextID = 0
    }

    /// Install the sudoers rule and retry connecting on success.
    ///
    /// Prompts the user for their admin password once via the system dialog.
    /// If installation succeeds, automatically retries the VPN connection.
    func installSudoers() {
        appendLog(L10n.Sudoers.install + "…")
        let success = PrivilegedExecution.installSudoers()
        if success {
            appendLog(L10n.Sudoers.installSuccess)
            state = .disconnected
            connect()
        } else {
            appendLog(L10n.Sudoers.installFailed)
        }
    }

    // MARK: - Internal (visible for testing)

    var isErrorState: Bool {
        if case .error = state { return true }
        return false
    }

    func appendLog(_ line: String) {
        let timestamp = Self.logDateFormatter.string(from: Date())
        let entry = LogEntry(id: logNextID, text: "[\(timestamp)] \(line)")
        log.append(entry)
        logNextID += 1
        if log.count > Constants.UI.logBufferLimit {
            log.removeFirst(log.count - Constants.UI.logBufferLimit)
        }
    }

    func handleOutput(_ line: String) {
        appendLog(line)

        if line.contains(Constants.LogPatterns.tunnelUp) ||
           line.contains(Constants.LogPatterns.connectedToGateway) {
            state = .connected
            connectedSince = Date()
        }

        // Detect the exact openfortivpn log line indicating the SAML HTTP proxy
        // is bound and accepting connections on its port.
        if line.contains(Constants.LogPatterns.samlProxyListening) {
            state = .waitingForSAML
            if !samlBrowserOpened {
                openSAMLLogin()
            }
        }
    }

    func handleTermination(status: Int32) {
        vpnProcess = nil
        connectedSince = nil

        switch state {
        case .disconnecting:
            state = .disconnected
            appendLog(L10n.Log.disconnected)
        case .connected:
            state = .disconnected
            appendLog(L10n.Log.unexpectedTermination(status))
        default:
            if status != 0 {
                state = .error(L10n.Error.connectionFailed)
                appendLog(L10n.Log.processExited(status))
            } else {
                state = .disconnected
            }
        }
    }

    // MARK: - Private

    private func openSAMLLogin() {
        samlBrowserOpened = true
        guard let url = settings.samlURL else { return }
        appendLog(L10n.Log.openingSAML(url.absoluteString))
        NSWorkspace.shared.open(url)
    }

    /// Attempt a TCP connection to `127.0.0.1:<port>` to verify the SAML proxy
    /// is listening. Retries up to 3 times with 1-second intervals.
    ///
    /// Returns `true` if the connection succeeds (proxy is ready).
    private nonisolated static func probeSAMLProxy(port: Int) async -> Bool {
        for _ in 0..<3 {
            if tcpConnect(host: Constants.Network.localhost, port: UInt16(port)) {
                return true
            }
            try? await Task.sleep(for: .seconds(1))
        }
        return false
    }

    /// Low-level TCP connect probe. Returns `true` if a connection was established.
    private nonisolated static func tcpConnect(host: String, port: UInt16) -> Bool {
        let sock = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { Darwin.close(sock) }

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                Darwin.connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }

    private static let logDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = Constants.UI.logDateFormat
        return f
    }()
}
