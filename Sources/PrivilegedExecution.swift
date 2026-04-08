import Foundation

/// Manages launching and terminating privileged processes using sudoers-based
/// password-free execution.
///
/// Requires a sudoers rule granting NOPASSWD access to `openfortivpn` and
/// `kill`. See `make install-sudoers` for setup.
enum PrivilegedExecution {
    /// Launch a long-running privileged command via `sudo -n`, streaming output.
    ///
    /// Uses `-n` (non-interactive) so `sudo` fails rather than prompting for
    /// a password. A sudoers NOPASSWD rule must be installed for the target
    /// executable. The returned `Process` is the actual `sudo` process, so
    /// terminating it sends SIGTERM directly to the child.
    ///
    /// - Parameters:
    ///   - executable: The executable path (e.g. "/opt/homebrew/bin/openfortivpn").
    ///   - arguments: Arguments to pass to the executable.
    ///   - outputHandler: Called with each line of combined stdout/stderr.
    ///   - terminationHandler: Called when the process exits.
    /// - Returns: The running `Process` handle, or `nil` if launch failed.
    @discardableResult
    static func run(
        executable: String,
        arguments: [String],
        outputHandler: @escaping @Sendable (String) -> Void,
        terminationHandler: @escaping @Sendable (Int32) -> Void
    ) -> Process? {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: Constants.Executables.sudo)
        // -n = non-interactive: fail rather than prompt for a password
        process.arguments = ["-n", executable] + arguments

        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let handleData: @Sendable (FileHandle) -> Void = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.components(separatedBy: .newlines) where !line.isEmpty {
                outputHandler(line)
            }
        }

        outputPipe.fileHandleForReading.readabilityHandler = handleData
        errorPipe.fileHandleForReading.readabilityHandler = handleData

        process.terminationHandler = { proc in
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            terminationHandler(proc.terminationStatus)
        }

        do {
            try process.run()
            return process
        } catch {
            outputHandler(L10n.Log.processStartFailed(error.localizedDescription))
            terminationHandler(-1)
            return nil
        }
    }

    /// Send a signal to a process by PID, using `sudo -n kill`.
    ///
    /// This is needed because the openfortivpn child process runs as root.
    /// Uses `-n` (non-interactive) so it never prompts for a password.
    static func kill(pid: Int32, signal: Int32 = Constants.Process.sigterm) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Constants.Executables.sudo)
        process.arguments = ["-n", Constants.Process.killCommand, "-\(signal)", "\(pid)"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            NSLog("PrivilegedExecution.kill: failed to launch sudo kill: %@", error.localizedDescription)
            return
        }
        process.waitUntilExit()
    }

    /// Find PIDs of processes matching a pattern (via `pgrep`).
    ///
    /// Uses `-x` for exact process name matching to avoid false positives
    /// from similarly-named processes.
    static func findPIDs(matching pattern: String) -> [Int32] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: Constants.Executables.pgrep)
        // -x matches exact process name only (not full command line)
        process.arguments = ["-x", pattern]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            NSLog("PrivilegedExecution.findPIDs: failed to launch pgrep: %@", error.localizedDescription)
            return []
        }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        return output
            .components(separatedBy: .newlines)
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }
    }

    /// Find and kill all openfortivpn processes with the given signal.
    ///
    /// This is a convenience method that combines `findPIDs` and `kill`.
    /// Safe to call from any thread (blocks until complete).
    static func killOpenfortivpnProcesses(signal: Int32) {
        let pids = findPIDs(matching: Constants.Process.openfortivpnName)
        for pid in pids {
            kill(pid: pid, signal: signal)
        }
    }

    /// Check whether the sudoers rule allows running openfortivpn without a password.
    ///
    /// Runs `sudo -n <openfortivpn> --version` which succeeds only if a
    /// NOPASSWD rule is configured for the resolved openfortivpn binary.
    static func isSudoersConfigured() -> Bool {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: Constants.Executables.sudo)
        // -n = non-interactive (fail rather than prompt)
        process.arguments = ["-n", VPNSettings.default.openfortivpnPath, Constants.Process.versionFlag]
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            NSLog("PrivilegedExecution.isSudoersConfigured: failed to launch sudo: %@", error.localizedDescription)
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// Install the sudoers NOPASSWD rule via `osascript` with administrator privileges.
    ///
    /// This prompts the user for their admin password once via the system dialog.
    /// The rule is written to `/etc/sudoers.d/openfortivpn-gui` using `visudo`
    /// (Packaging Guideline #1).
    ///
    /// - Returns: `true` if the rule was installed successfully.
    @discardableResult
    static func installSudoers() -> Bool {
        let openfortivpnPath = VPNSettings.default.openfortivpnPath
        let user = NSUserName()
        let rule = "\(user) ALL=(root) NOPASSWD: \(openfortivpnPath), \(Constants.Executables.kill)"
        let shellCommand = "echo '\(rule)' | EDITOR='tee' visudo -f \(Constants.Sudoers.filePath)"
        let script = "do shell script \"\(shellCommand)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Constants.Executables.osascript)
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            NSLog("PrivilegedExecution.installSudoers: failed to launch osascript: %@", error.localizedDescription)
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
}
