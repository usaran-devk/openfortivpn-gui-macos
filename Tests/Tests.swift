import Foundation

// ============================================================================
// Unit tests for OpenFortiVPN-GUI
// Run with: make test
// ============================================================================

/// Minimal test framework for running without XCTest/SPM.
nonisolated(unsafe) var testsPassed = 0
nonisolated(unsafe) var testsFailed = 0
nonisolated(unsafe) var currentTest = ""

func describe(_ name: String, _ block: () -> Void) {
    currentTest = name
    print("\n\(name)")
    block()
}

func it(_ description: String, _ block: () throws -> Void) {
    do {
        try block()
        testsPassed += 1
        print("  PASS  \(description)")
    } catch {
        testsFailed += 1
        print("  FAIL  \(description) - \(error)")
    }
}

/// Test helper for `@MainActor`-isolated code.
///
/// Uses `MainActor.assumeIsolated` (safe because the test binary runs on
/// the main thread) and reports pass/fail via the global counters.
func mainActorIt(_ description: String, _ block: @MainActor () throws -> Void) {
    MainActor.assumeIsolated {
        do {
            try block()
            testsPassed += 1
            print("  PASS  \(description)")
        } catch {
            testsFailed += 1
            print("  FAIL  \(description) - \(error)")
        }
    }
}

func expect<T: Equatable>(_ actual: T, toBe expected: T, file: String = #file, line: Int = #line) throws {
    guard actual == expected else {
        throw TestError.assertion("Expected \(expected), got \(actual) at \(file):\(line)")
    }
}

func expectTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard condition else {
        throw TestError.assertion("Expected true\(message.isEmpty ? "" : ": \(message)") at \(file):\(line)")
    }
}

func expectFalse(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard !condition else {
        throw TestError.assertion("Expected false\(message.isEmpty ? "" : ": \(message)") at \(file):\(line)")
    }
}

func expectNil<T>(_ value: T?, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard value == nil else {
        throw TestError.assertion("Expected nil, got \(value!)\(message.isEmpty ? "" : ": \(message)") at \(file):\(line)")
    }
}

func expectNotNil<T>(_ value: T?, _ message: String = "", file: String = #file, line: Int = #line) throws {
    guard value != nil else {
        throw TestError.assertion("Expected non-nil\(message.isEmpty ? "" : ": \(message)") at \(file):\(line)")
    }
}

enum TestError: Error, CustomStringConvertible {
    case assertion(String)
    var description: String {
        switch self { case .assertion(let msg): return msg }
    }
}

// ============================================================================
// Test runner entry point
// ============================================================================

@main
struct TestRunner {
    static func main() {
        testVPNState()
        testVPNSettings()
        testVPNSettingsEdgeCases()
        testVPNSettingsPersistence()
        testLocalization()
        testLocalizationCompleteness()
        testLocalizationLogMessages()
        testLocalizationSudoers()
        testPrivilegedExecution()
        testVPNManager()
        testConstants()

        print("\n========================================")
        print("Tests: \(testsPassed + testsFailed) total, \(testsPassed) passed, \(testsFailed) failed")
        print("========================================")

        if testsFailed > 0 {
            exit(1)
        }
    }
}

// ============================================================================
// VPNState Tests
// ============================================================================

func testVPNState() {
    describe("VPNState") {
        it("has correct equality for simple cases") {
            try expect(VPNState.disconnected, toBe: VPNState.disconnected)
            try expect(VPNState.connecting, toBe: VPNState.connecting)
            try expect(VPNState.connected, toBe: VPNState.connected)
            try expect(VPNState.waitingForSAML, toBe: VPNState.waitingForSAML)
            try expect(VPNState.disconnecting, toBe: VPNState.disconnecting)
        }

        it("has correct equality for error cases") {
            try expect(VPNState.error("foo"), toBe: VPNState.error("foo"))
            try expectFalse(VPNState.error("foo") == VPNState.error("bar"))
        }

        it("is not equal across different states") {
            try expectFalse(VPNState.disconnected == VPNState.connected)
            try expectFalse(VPNState.connecting == VPNState.disconnecting)
            try expectFalse(VPNState.error("x") == VPNState.disconnected)
        }

        it("reports isActive correctly") {
            try expectTrue(VPNState.connecting.isActive)
            try expectTrue(VPNState.waitingForSAML.isActive)
            try expectTrue(VPNState.connected.isActive)
            try expectFalse(VPNState.disconnected.isActive)
            try expectFalse(VPNState.disconnecting.isActive)
            try expectFalse(VPNState.error("x").isActive)
        }

        it("provides localized descriptions") {
            try expectFalse(VPNState.disconnected.localizedDescription.isEmpty)
            try expectFalse(VPNState.connecting.localizedDescription.isEmpty)
            try expectFalse(VPNState.connected.localizedDescription.isEmpty)
            try expectTrue(VPNState.error("test").localizedDescription.contains("test"))
        }

        it("error state includes the error message in description") {
            let desc = VPNState.error("timeout").localizedDescription
            try expectTrue(desc.contains("timeout"), "Description should contain the error message")
        }

        it("error state with empty message still has a description") {
            let desc = VPNState.error("").localizedDescription
            try expectFalse(desc.isEmpty, "Description should not be empty even with empty error")
        }

        it("disconnecting is not active (cannot connect during disconnect)") {
            try expectFalse(VPNState.disconnecting.isActive)
        }

        it("all states have unique descriptions") {
            let descriptions = [
                VPNState.disconnected.localizedDescription,
                VPNState.connecting.localizedDescription,
                VPNState.waitingForSAML.localizedDescription,
                VPNState.connected.localizedDescription,
                VPNState.disconnecting.localizedDescription,
            ]
            let uniqueDescriptions = Set(descriptions)
            try expect(uniqueDescriptions.count, toBe: descriptions.count)
        }
    }
}

// ============================================================================
// VPNSettings Tests
// ============================================================================

func testVPNSettings() {
    describe("VPNSettings") {
        it("has sensible defaults") {
            let d = VPNSettings.default
            try expect(d.vpnHost, toBe: "")
            try expect(d.samlPort, toBe: 8020)
            try expect(d.setDNS, toBe: false)
            try expect(d.peerDNS, toBe: true)
        }

        it("generates correct openfortivpn command with defaults") {
            let s = VPNSettings.default
            let cmd = s.openfortivpnCommand
            try expectTrue(cmd.contains("openfortivpn"))
            try expectTrue(cmd.contains("--set-dns=0"))
            try expectTrue(cmd.contains("--pppd-use-peerdns=1"))
            try expectTrue(cmd.contains("--saml-login=8020"))
        }

        it("generates command with custom settings") {
            let s = VPNSettings(vpnHost: "my.vpn.host", samlPort: 9999, setDNS: true, peerDNS: false)
            let cmd = s.openfortivpnCommand
            try expectTrue(cmd.contains("openfortivpn my.vpn.host"))
            try expectTrue(cmd.contains("--set-dns=1"))
            try expectTrue(cmd.contains("--pppd-use-peerdns=0"))
            try expectTrue(cmd.contains("--saml-login=9999"))
        }

        it("generates correct SAML URL with custom host") {
            let s = VPNSettings(vpnHost: "vpn.example.com", samlPort: 8020, setDNS: false, peerDNS: true)
            let url = s.samlURL
            try expect(url?.absoluteString, toBe: "https://vpn.example.com/remote/saml/start?redirect=1")
        }

        it("default settings produce nil SAML URL (empty host)") {
            let s = VPNSettings.default
            try expectNil(s.samlURL, "Empty default host should produce nil URL")
        }

        it("encodes and decodes via Codable") {
            let original = VPNSettings(vpnHost: "test.host", samlPort: 1234, setDNS: true, peerDNS: false)
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(VPNSettings.self, from: data)
            try expect(decoded, toBe: original)
        }

        it("generates correct arguments array with defaults") {
            let s = VPNSettings.default
            let args = s.openfortivpnArguments
            try expect(args.count, toBe: 4)
            try expect(args[0], toBe: "")
            try expect(args[1], toBe: "--set-dns=0")
            try expect(args[2], toBe: "--pppd-use-peerdns=1")
            try expect(args[3], toBe: "--saml-login=8020")
        }

        it("generates arguments with custom settings") {
            let s = VPNSettings(vpnHost: "other.host", samlPort: 5000, setDNS: true, peerDNS: false)
            let args = s.openfortivpnArguments
            try expect(args[0], toBe: "other.host")
            try expect(args[1], toBe: "--set-dns=1")
            try expect(args[2], toBe: "--pppd-use-peerdns=0")
            try expect(args[3], toBe: "--saml-login=5000")
        }

        it("resolves openfortivpn path to an existing binary") {
            let s = VPNSettings.default
            let path = s.openfortivpnPath
            try expectFalse(path.isEmpty, "Path should not be empty")
            // Path should end with openfortivpn
            try expectTrue(path.hasSuffix("openfortivpn"), "Path should end with openfortivpn: \(path)")
        }
    }
}

// ============================================================================
// VPNSettings Edge Case Tests
// ============================================================================

func testVPNSettingsEdgeCases() {
    describe("VPNSettings Edge Cases") {
        it("samlURL returns nil for empty host") {
            let s = VPNSettings(vpnHost: "", samlPort: 8020, setDNS: false, peerDNS: true)
            try expectNil(s.samlURL, "Empty host should produce nil URL")
        }

        it("samlURL returns nil for whitespace-only host") {
            let s = VPNSettings(vpnHost: "   ", samlPort: 8020, setDNS: false, peerDNS: true)
            try expectNil(s.samlURL, "Whitespace host should produce nil URL")
        }

        it("samlURL trims whitespace from host") {
            let s = VPNSettings(vpnHost: "  example.com  ", samlPort: 8020, setDNS: false, peerDNS: true)
            let url = s.samlURL
            try expectNotNil(url)
            try expect(url?.absoluteString, toBe: "https://example.com/remote/saml/start?redirect=1")
        }

        it("openfortivpnCommand and arguments are consistent") {
            let s = VPNSettings(vpnHost: "test.host", samlPort: 3000, setDNS: true, peerDNS: false)
            let cmd = s.openfortivpnCommand
            let args = s.openfortivpnArguments
            // The command should contain all argument values
            for arg in args {
                try expectTrue(cmd.contains(arg), "Command should contain argument: \(arg)")
            }
        }

        it("handles very large port numbers") {
            let s = VPNSettings(vpnHost: "host", samlPort: 65535, setDNS: false, peerDNS: true)
            try expectTrue(s.openfortivpnArguments.contains("--saml-login=65535"))
        }

        it("clamps zero port to minimum") {
            let s = VPNSettings(vpnHost: "host", samlPort: 0, setDNS: false, peerDNS: true)
            try expectTrue(s.openfortivpnArguments.contains("--saml-login=1"))
        }

        it("Codable round-trip preserves all field values") {
            let settings = [
                VPNSettings(vpnHost: "", samlPort: 0, setDNS: false, peerDNS: false),
                VPNSettings(vpnHost: "a.b.c.d", samlPort: 65535, setDNS: true, peerDNS: true),
                VPNSettings.default,
            ]
            for original in settings {
                let data = try JSONEncoder().encode(original)
                let decoded = try JSONDecoder().decode(VPNSettings.self, from: data)
                try expect(decoded.vpnHost, toBe: original.vpnHost)
                try expect(decoded.samlPort, toBe: original.samlPort)
                try expect(decoded.setDNS, toBe: original.setDNS)
                try expect(decoded.peerDNS, toBe: original.peerDNS)
            }
        }

        it("Equatable compares all fields") {
            let a = VPNSettings(vpnHost: "a", samlPort: 1, setDNS: true, peerDNS: true)
            let b = VPNSettings(vpnHost: "a", samlPort: 1, setDNS: true, peerDNS: false)
            try expectFalse(a == b, "Settings differing only in peerDNS should not be equal")

            let c = VPNSettings(vpnHost: "a", samlPort: 1, setDNS: false, peerDNS: true)
            try expectFalse(a == c, "Settings differing only in setDNS should not be equal")

            let d = VPNSettings(vpnHost: "a", samlPort: 2, setDNS: true, peerDNS: true)
            try expectFalse(a == d, "Settings differing only in port should not be equal")

            let e = VPNSettings(vpnHost: "b", samlPort: 1, setDNS: true, peerDNS: true)
            try expectFalse(a == e, "Settings differing only in host should not be equal")
        }

        it("openfortivpnPath always ends with openfortivpn") {
            // Test with various settings - path resolution shouldn't depend on settings
            let configs = [
                VPNSettings.default,
                VPNSettings(vpnHost: "x", samlPort: 1, setDNS: true, peerDNS: true),
            ]
            for s in configs {
                try expectTrue(s.openfortivpnPath.hasSuffix("openfortivpn"))
            }
        }

        it("default static property returns consistent values") {
            let a = VPNSettings.default
            let b = VPNSettings.default
            try expect(a, toBe: b)
        }

        it("normalizedHost trims whitespace") {
            let s = VPNSettings(vpnHost: "  vpn.example.com  ", samlPort: 8020, setDNS: false, peerDNS: true)
            try expect(s.normalizedHost, toBe: "vpn.example.com")
        }

        it("normalizedHost strips https:// prefix") {
            let s = VPNSettings(vpnHost: "https://vpn.example.com", samlPort: 8020, setDNS: false, peerDNS: true)
            try expect(s.normalizedHost, toBe: "vpn.example.com")
        }

        it("normalizedHost strips http:// prefix") {
            let s = VPNSettings(vpnHost: "http://vpn.example.com", samlPort: 8020, setDNS: false, peerDNS: true)
            try expect(s.normalizedHost, toBe: "vpn.example.com")
        }

        it("normalizedHost strips scheme case-insensitively") {
            let s = VPNSettings(vpnHost: "HTTPS://VPN.EXAMPLE.COM", samlPort: 8020, setDNS: false, peerDNS: true)
            try expect(s.normalizedHost, toBe: "VPN.EXAMPLE.COM")
        }

        it("normalizedHost trims whitespace and strips scheme together") {
            let s = VPNSettings(vpnHost: "  https://vpn.example.com  ", samlPort: 8020, setDNS: false, peerDNS: true)
            try expect(s.normalizedHost, toBe: "vpn.example.com")
        }

        it("normalizedHost returns empty for empty host") {
            let s = VPNSettings(vpnHost: "", samlPort: 8020, setDNS: false, peerDNS: true)
            try expect(s.normalizedHost, toBe: "")
        }

        it("normalizedHost returns empty for whitespace-only host") {
            let s = VPNSettings(vpnHost: "   ", samlPort: 8020, setDNS: false, peerDNS: true)
            try expect(s.normalizedHost, toBe: "")
        }

        it("normalizedHost passes through bare hostname unchanged") {
            let s = VPNSettings(vpnHost: "vpn.example.com", samlPort: 8020, setDNS: false, peerDNS: true)
            try expect(s.normalizedHost, toBe: "vpn.example.com")
        }

        it("openfortivpnArguments uses normalizedHost") {
            let s = VPNSettings(vpnHost: "  https://vpn.example.com  ", samlPort: 8020, setDNS: false, peerDNS: true)
            try expect(s.openfortivpnArguments[0], toBe: "vpn.example.com")
        }

        it("clampedPort returns port when within range") {
            let s = VPNSettings(vpnHost: "", samlPort: 8020, setDNS: false, peerDNS: true)
            try expect(s.clampedPort, toBe: 8020)
        }

        it("clampedPort clamps zero to minimum") {
            let s = VPNSettings(vpnHost: "", samlPort: 0, setDNS: false, peerDNS: true)
            try expect(s.clampedPort, toBe: 1)
        }

        it("clampedPort clamps negative to minimum") {
            let s = VPNSettings(vpnHost: "", samlPort: -5, setDNS: false, peerDNS: true)
            try expect(s.clampedPort, toBe: 1)
        }

        it("clampedPort clamps above max to maximum") {
            let s = VPNSettings(vpnHost: "", samlPort: 70000, setDNS: false, peerDNS: true)
            try expect(s.clampedPort, toBe: 65535)
        }

        it("clampedPort accepts boundary values") {
            let sMin = VPNSettings(vpnHost: "", samlPort: 1, setDNS: false, peerDNS: true)
            try expect(sMin.clampedPort, toBe: 1)
            let sMax = VPNSettings(vpnHost: "", samlPort: 65535, setDNS: false, peerDNS: true)
            try expect(sMax.clampedPort, toBe: 65535)
        }

        it("samlURL uses normalizedHost for scheme-prefixed input") {
            let s = VPNSettings(vpnHost: "https://vpn.example.com", samlPort: 8020, setDNS: false, peerDNS: true)
            try expect(s.samlURL?.absoluteString, toBe: "https://vpn.example.com/remote/saml/start?redirect=1")
        }
    }
}

// ============================================================================
// VPNSettings Persistence Tests
// ============================================================================

func testVPNSettingsPersistence() {
    describe("VPNSettings Persistence") {
        it("save and load round-trip via UserDefaults") {
            let custom = VPNSettings(vpnHost: "test-persistence.host", samlPort: 7777, setDNS: true, peerDNS: false)
            custom.save()
            let loaded = VPNSettings.load()
            try expect(loaded, toBe: custom)

            // Restore defaults to not pollute other tests
            VPNSettings.default.save()
        }

        it("load returns defaults when nothing is stored") {
            // Clear storage
            UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.vpnSettings)
            let loaded = VPNSettings.load()
            try expect(loaded, toBe: VPNSettings.default)
        }

        it("load returns defaults when stored data is corrupted") {
            UserDefaults.standard.set(Data([0x00, 0xFF]), forKey: Constants.StorageKeys.vpnSettings)
            let loaded = VPNSettings.load()
            try expect(loaded, toBe: VPNSettings.default)

            // Clean up
            UserDefaults.standard.removeObject(forKey: Constants.StorageKeys.vpnSettings)
        }
    }
}

// ============================================================================
// Localization Tests
// ============================================================================

func testLocalization() {
    describe("Localization") {
        it("returns non-empty strings for all state translations") {
            try expectFalse(L10n.State.disconnected.isEmpty)
            try expectFalse(L10n.State.connecting.isEmpty)
            try expectFalse(L10n.State.waitingForSAML.isEmpty)
            try expectFalse(L10n.State.connected.isEmpty)
            try expectFalse(L10n.State.disconnecting.isEmpty)
            try expectFalse(L10n.State.error.isEmpty)
        }

        it("returns non-empty strings for all action translations") {
            try expectFalse(L10n.Action.connect.isEmpty)
            try expectFalse(L10n.Action.disconnect.isEmpty)
            try expectFalse(L10n.Action.quit.isEmpty)
        }

        it("returns non-empty strings for all settings translations") {
            try expectFalse(L10n.Settings.vpnHost.isEmpty)
            try expectFalse(L10n.Settings.samlPort.isEmpty)
            try expectFalse(L10n.Settings.setDNS.isEmpty)
            try expectFalse(L10n.Settings.peerDNS.isEmpty)
            try expectFalse(L10n.Settings.save.isEmpty)
            try expectFalse(L10n.Settings.restoreDefaults.isEmpty)
        }

        it("locale detection returns en or de") {
            let locale = L10n.locale
            try expectTrue(locale == "en" || locale == "de", "Locale should be en or de, got: \(locale)")
        }
    }
}

// ============================================================================
// Localization Completeness Tests
// ============================================================================

func testLocalizationCompleteness() {
    describe("Localization Completeness") {
        it("returns non-empty strings for menu bar translations") {
            try expectFalse(L10n.MenuBar.label.isEmpty)
        }

        it("returns non-empty strings for log translations") {
            try expectFalse(L10n.Log.title.isEmpty)
        }

        it("returns non-empty strings for error translations") {
            try expectFalse(L10n.Error.connectionFailed.isEmpty)
            try expectFalse(L10n.Error.sudoersNotConfigured.isEmpty)
            try expectFalse(L10n.Error.vpnHostEmpty.isEmpty)
        }

        it("returns non-empty strings for settings title") {
            try expectFalse(L10n.Settings.title.isEmpty)
        }

        it("returns non-empty strings for DNS section and footer") {
            try expectFalse(L10n.Settings.dnsSection.isEmpty)
            try expectFalse(L10n.Settings.dnsFooter.isEmpty)
        }

        it("returns non-empty strings for connection section") {
            try expectFalse(L10n.Settings.connectionSection.isEmpty)
        }

        it("invalidPort returns non-empty string with range") {
            let msg = L10n.Settings.invalidPort(1, 65535)
            try expectFalse(msg.isEmpty)
            try expectTrue(msg.contains("1"), "Should contain min port")
            try expectTrue(msg.contains("65535"), "Should contain max port")
        }

        it("hostRequired returns non-empty string") {
            try expectFalse(L10n.Settings.hostRequired.isEmpty)
        }

        it("state descriptions are different from each other") {
            // Verify the localization returns distinct strings for each state
            let states = [
                L10n.State.disconnected,
                L10n.State.connecting,
                L10n.State.waitingForSAML,
                L10n.State.connected,
                L10n.State.disconnecting,
                L10n.State.error,
            ]
            let unique = Set(states)
            try expect(unique.count, toBe: states.count)
        }
    }
}

// ============================================================================
// Localization Log Messages Tests
// ============================================================================

func testLocalizationLogMessages() {
    describe("Localization Log Messages") {
        it("starting returns non-empty string with arguments") {
            let msg = L10n.Log.starting("test.example.com --set-dns=0")
            try expectFalse(msg.isEmpty)
            try expectTrue(msg.contains("test.example.com"), "Should contain the arguments")
        }

        it("disconnecting returns non-empty string") {
            try expectFalse(L10n.Log.disconnecting.isEmpty)
        }

        it("disconnected returns non-empty string") {
            try expectFalse(L10n.Log.disconnected.isEmpty)
        }

        it("openingSAML returns non-empty string with URL") {
            let msg = L10n.Log.openingSAML("https://example.com/saml")
            try expectFalse(msg.isEmpty)
            try expectTrue(msg.contains("https://example.com/saml"), "Should contain the URL")
        }

        it("unexpectedTermination returns non-empty string with exit code") {
            let msg = L10n.Log.unexpectedTermination(42)
            try expectFalse(msg.isEmpty)
            try expectTrue(msg.contains("42"), "Should contain the exit code")
        }

        it("processExited returns non-empty string with exit code") {
            let msg = L10n.Log.processExited(0)
            try expectFalse(msg.isEmpty)
            try expectTrue(msg.contains("0"), "Should contain the exit code")
        }

        it("processStartFailed returns non-empty string with error") {
            let msg = L10n.Log.processStartFailed("permission denied")
            try expectFalse(msg.isEmpty)
            try expectTrue(msg.contains("permission denied"), "Should contain the error message")
        }

        it("probingSAMLProxy returns non-empty string with port") {
            let msg = L10n.Log.probingSAMLProxy(8020)
            try expectFalse(msg.isEmpty)
            try expectTrue(msg.contains("8020"), "Should contain the port number")
        }

        it("samlProxyNotReady returns non-empty string") {
            try expectFalse(L10n.Log.samlProxyNotReady.isEmpty)
        }
    }
}

// ============================================================================
// Localization Sudoers Alert Tests
// ============================================================================

func testLocalizationSudoers() {
    describe("Localization Sudoers Alert") {
        it("alertTitle returns non-empty string") {
            try expectFalse(L10n.Sudoers.alertTitle.isEmpty)
        }

        it("alertMessage returns non-empty string") {
            try expectFalse(L10n.Sudoers.alertMessage.isEmpty)
        }

        it("install returns non-empty string") {
            try expectFalse(L10n.Sudoers.install.isEmpty)
        }

        it("cancel returns non-empty string") {
            try expectFalse(L10n.Sudoers.cancel.isEmpty)
        }

        it("installSuccess returns non-empty string") {
            try expectFalse(L10n.Sudoers.installSuccess.isEmpty)
        }

        it("installFailed returns non-empty string") {
            try expectFalse(L10n.Sudoers.installFailed.isEmpty)
        }

        it("all sudoers strings are distinct") {
            let strings = [
                L10n.Sudoers.alertTitle,
                L10n.Sudoers.alertMessage,
                L10n.Sudoers.install,
                L10n.Sudoers.cancel,
                L10n.Sudoers.installSuccess,
                L10n.Sudoers.installFailed,
            ]
            let unique = Set(strings)
            try expect(unique.count, toBe: strings.count)
        }
    }
}

// ============================================================================
// PrivilegedExecution Tests
// ============================================================================

func testPrivilegedExecution() {
    describe("PrivilegedExecution") {
        it("findPIDs returns an array (possibly empty) for a nonexistent process") {
            let pids = PrivilegedExecution.findPIDs(matching: "nonexistent_process_xyz_12345")
            try expect(pids.count, toBe: 0)
        }

        it("findPIDs returns PIDs for a known running process") {
            // Finder is always running on macOS
            let pids = PrivilegedExecution.findPIDs(matching: "Finder")
            try expectTrue(pids.count > 0, "Finder should always be running")
            try expectTrue(pids[0] > 0, "PIDs should be positive")
        }

        it("findPIDs returns only positive integers") {
            let pids = PrivilegedExecution.findPIDs(matching: "launchd")
            for pid in pids {
                try expectTrue(pid > 0, "PID should be positive, got \(pid)")
            }
        }

    }
}

// ============================================================================
// Constants Tests
// ============================================================================

func testConstants() {
    describe("Constants.Executables") {
        it("sudo path ends with sudo") {
            try expectTrue(Constants.Executables.sudo.hasSuffix("sudo"))
        }

        it("sudo path is absolute") {
            try expectTrue(Constants.Executables.sudo.hasPrefix("/"))
        }

        it("pgrep path ends with pgrep") {
            try expectTrue(Constants.Executables.pgrep.hasSuffix("pgrep"))
        }

        it("pgrep path is absolute") {
            try expectTrue(Constants.Executables.pgrep.hasPrefix("/"))
        }

        it("kill path ends with kill") {
            try expectTrue(Constants.Executables.kill.hasSuffix("kill"))
        }

        it("kill path is absolute") {
            try expectTrue(Constants.Executables.kill.hasPrefix("/"))
        }

        it("osascript path ends with osascript") {
            try expectTrue(Constants.Executables.osascript.hasSuffix("osascript"))
        }

        it("osascript path is absolute") {
            try expectTrue(Constants.Executables.osascript.hasPrefix("/"))
        }

        it("openfortivpn search paths are non-empty") {
            try expectTrue(Constants.Executables.openfortivpnSearchPaths.count > 0)
        }

        it("openfortivpn search paths all end with openfortivpn") {
            for path in Constants.Executables.openfortivpnSearchPaths {
                try expectTrue(path.hasSuffix("openfortivpn"), "Path should end with openfortivpn: \(path)")
            }
        }

        it("openfortivpn search paths are all absolute") {
            for path in Constants.Executables.openfortivpnSearchPaths {
                try expectTrue(path.hasPrefix("/"), "Path should be absolute: \(path)")
            }
        }

        it("openfortivpn fallback ends with openfortivpn") {
            try expectTrue(Constants.Executables.openfortivpnFallback.hasSuffix("openfortivpn"))
        }
    }

    describe("Constants.Process") {
        it("openfortivpnName is correct") {
            try expect(Constants.Process.openfortivpnName, toBe: "openfortivpn")
        }

        it("killCommand is non-empty") {
            try expectFalse(Constants.Process.killCommand.isEmpty)
        }

        it("versionFlag starts with --") {
            try expectTrue(Constants.Process.versionFlag.hasPrefix("--"))
        }

        it("sigterm is 15") {
            try expect(Constants.Process.sigterm, toBe: 15)
        }

        it("sigkill is 9") {
            try expect(Constants.Process.sigkill, toBe: 9)
        }
    }

    describe("Constants.LogPatterns") {
        it("tunnelUp is non-empty") {
            try expectFalse(Constants.LogPatterns.tunnelUp.isEmpty)
        }

        it("connectedToGateway is non-empty") {
            try expectFalse(Constants.LogPatterns.connectedToGateway.isEmpty)
        }

        it("samlProxyListening is non-empty") {
            try expectFalse(Constants.LogPatterns.samlProxyListening.isEmpty)
        }
    }

    describe("Constants.Network") {
        it("localhost is 127.0.0.1") {
            try expect(Constants.Network.localhost, toBe: "127.0.0.1")
        }

        it("samlLoginPath starts with /") {
            try expectTrue(Constants.Network.samlLoginPath.hasPrefix("/"))
        }

        it("samlLoginPath contains saml") {
            try expectTrue(Constants.Network.samlLoginPath.contains("saml"))
        }

        it("portMin is 1") {
            try expect(Constants.Network.portMin, toBe: 1)
        }

        it("portMax is 65535") {
            try expect(Constants.Network.portMax, toBe: 65535)
        }

        it("schemePrefixes contains https:// and http://") {
            try expectTrue(Constants.Network.schemePrefixes.contains("https://"))
            try expectTrue(Constants.Network.schemePrefixes.contains("http://"))
        }
    }

    describe("Constants.Defaults") {
        it("vpnHost matches expected default") {
            try expect(Constants.Defaults.vpnHost, toBe: "")
        }

        it("samlPort matches expected default") {
            try expect(Constants.Defaults.samlPort, toBe: 8020)
        }
    }

    describe("Constants.StorageKeys") {
        it("vpnSettings key is non-empty") {
            try expectFalse(Constants.StorageKeys.vpnSettings.isEmpty)
        }
    }

    describe("Constants.Sudoers") {
        it("filePath is absolute") {
            try expectTrue(Constants.Sudoers.filePath.hasPrefix("/"))
        }

        it("filePath is in sudoers.d directory") {
            try expectTrue(Constants.Sudoers.filePath.contains("sudoers.d"))
        }
    }

    describe("Constants.UI") {
        it("popover dimensions are positive") {
            try expectTrue(Constants.UI.popoverWidth > 0)
            try expectTrue(Constants.UI.popoverHeight > 0)
        }

        it("settings dimensions are positive") {
            try expectTrue(Constants.UI.settingsWidth > 0)
            try expectTrue(Constants.UI.settingsHeight > 0)
        }

        it("logBufferLimit is positive") {
            try expectTrue(Constants.UI.logBufferLimit > 0)
        }

        it("logDateFormat is non-empty") {
            try expectFalse(Constants.UI.logDateFormat.isEmpty)
        }

        it("appDisplayName is non-empty") {
            try expectFalse(Constants.UI.appDisplayName.isEmpty)
        }

        it("layout padding constants are positive") {
            try expectTrue(Constants.UI.sectionPaddingH > 0)
            try expectTrue(Constants.UI.sectionPaddingV > 0)
            try expectTrue(Constants.UI.compactPaddingV > 0)
        }

        it("status indicator size is positive") {
            try expectTrue(Constants.UI.statusIndicatorSize > 0)
        }
    }

    describe("Constants.Symbols") {
        it("all symbol names are non-empty") {
            let symbols = [
                Constants.Symbols.shieldDefault,
                Constants.Symbols.shieldConnected,
                Constants.Symbols.shieldSAML,
                Constants.Symbols.shieldError,
                Constants.Symbols.appIcon,
                Constants.Symbols.trash,
                Constants.Symbols.settings,
            ]
            for symbol in symbols {
                try expectFalse(symbol.isEmpty, "Symbol name should not be empty")
            }
        }
    }
}

// ============================================================================
// VPNManager Tests
// ============================================================================

func testVPNManager() {
    describe("VPNManager.connect validation") {
        mainActorIt("sets error state when host is empty") {
            let vm = VPNManager()
            vm.settings = VPNSettings(vpnHost: "", samlPort: 8020, setDNS: false, peerDNS: true)
            vm.connect()
            if case .error = vm.state {
                // expected
            } else {
                throw TestError.assertion("Expected error state for empty host, got \(vm.state)")
            }
        }

        mainActorIt("sets error state when host is whitespace only") {
            let vm = VPNManager()
            vm.settings = VPNSettings(vpnHost: "   ", samlPort: 8020, setDNS: false, peerDNS: true)
            vm.connect()
            if case .error = vm.state {
                // expected
            } else {
                throw TestError.assertion("Expected error state for whitespace host, got \(vm.state)")
            }
        }

        mainActorIt("logs error message when host is empty") {
            let vm = VPNManager()
            vm.settings = VPNSettings(vpnHost: "", samlPort: 8020, setDNS: false, peerDNS: true)
            vm.connect()
            try expectTrue(vm.log.count > 0, "Should have log entries")
            let lastLog = vm.log.last?.text ?? ""
            try expectTrue(lastLog.contains(L10n.Error.vpnHostEmpty), "Log should contain host empty error")
        }
    }

    describe("VPNManager.handleOutput") {
        mainActorIt("detects tunnel up and transitions to connected") {
            let vm = VPNManager()
            vm.state = .connecting
            vm.handleOutput("INFO: \(Constants.LogPatterns.tunnelUp).")
            try expect(vm.state, toBe: VPNState.connected)
        }

        mainActorIt("detects connected to gateway and transitions to connected") {
            let vm = VPNManager()
            vm.state = .connecting
            vm.handleOutput("INFO: \(Constants.LogPatterns.connectedToGateway).")
            try expect(vm.state, toBe: VPNState.connected)
        }

        mainActorIt("detects SAML proxy listening and transitions to waitingForSAML") {
            let vm = VPNManager()
            vm.state = .connecting
            vm.handleOutput("INFO: \(Constants.LogPatterns.samlProxyListening) 8020")
            try expect(vm.state, toBe: VPNState.waitingForSAML)
        }

        mainActorIt("appends output lines to the log") {
            let vm = VPNManager()
            vm.handleOutput("test line 1")
            vm.handleOutput("test line 2")
            try expect(vm.log.count, toBe: 2)
            try expectTrue(vm.log[0].text.contains("test line 1"))
            try expectTrue(vm.log[1].text.contains("test line 2"))
        }

        mainActorIt("does not change state for unrecognized output") {
            let vm = VPNManager()
            vm.state = .connecting
            vm.handleOutput("some random log line")
            try expect(vm.state, toBe: VPNState.connecting)
        }
    }

    describe("VPNManager.handleTermination") {
        mainActorIt("transitions from disconnecting to disconnected") {
            let vm = VPNManager()
            vm.state = .disconnecting
            vm.handleTermination(status: 0)
            try expect(vm.state, toBe: VPNState.disconnected)
        }

        mainActorIt("transitions from connected to disconnected on unexpected termination") {
            let vm = VPNManager()
            vm.state = .connected
            vm.handleTermination(status: 1)
            try expect(vm.state, toBe: VPNState.disconnected)
            try expectTrue(vm.log.last?.text.contains("1") ?? false, "Should log exit code")
        }

        mainActorIt("transitions to error on non-zero exit from connecting") {
            let vm = VPNManager()
            vm.state = .connecting
            vm.handleTermination(status: 1)
            if case .error = vm.state {
                // expected
            } else {
                throw TestError.assertion("Expected error state, got \(vm.state)")
            }
        }

        mainActorIt("transitions to disconnected on zero exit from connecting") {
            let vm = VPNManager()
            vm.state = .connecting
            vm.handleTermination(status: 0)
            try expect(vm.state, toBe: VPNState.disconnected)
        }

        mainActorIt("clears connectionDate on termination") {
            let vm = VPNManager()
            vm.state = .connected
            vm.handleTermination(status: 0)
            try expectNil(vm.connectionDate)
        }
    }

    describe("VPNManager.appendLog") {
        mainActorIt("adds timestamped entries") {
            let vm = VPNManager()
            vm.appendLog("hello")
            try expect(vm.log.count, toBe: 1)
            try expectTrue(vm.log[0].text.contains("hello"))
            // Timestamp format: [HH:mm:ss]
            try expectTrue(vm.log[0].text.hasPrefix("["))
        }

        mainActorIt("assigns monotonically increasing IDs") {
            let vm = VPNManager()
            vm.appendLog("a")
            vm.appendLog("b")
            vm.appendLog("c")
            try expect(vm.log[0].id, toBe: 0)
            try expect(vm.log[1].id, toBe: 1)
            try expect(vm.log[2].id, toBe: 2)
            try expect(vm.logNextID, toBe: 3)
        }

        mainActorIt("trims log when exceeding buffer limit") {
            let vm = VPNManager()
            let limit = Constants.UI.logBufferLimit
            for i in 0..<(limit + 10) {
                vm.appendLog("line \(i)")
            }
            try expect(vm.log.count, toBe: limit)
            // First entry should be line 10 (first 10 were trimmed)
            try expectTrue(vm.log[0].text.contains("line 10"))
            // IDs should still be monotonic from the original sequence
            try expect(vm.log[0].id, toBe: 10)
        }
    }

    describe("VPNManager.clearLog") {
        mainActorIt("clears log and resets ID counter") {
            let vm = VPNManager()
            vm.appendLog("a")
            vm.appendLog("b")
            vm.clearLog()
            try expect(vm.log.count, toBe: 0)
            try expect(vm.logNextID, toBe: 0)
        }
    }

    describe("VPNManager.isErrorState") {
        mainActorIt("returns true for error state") {
            let vm = VPNManager()
            vm.state = .error("test")
            try expectTrue(vm.isErrorState)
        }

        mainActorIt("returns false for non-error states") {
            let vm = VPNManager()
            let states: [VPNState] = [.disconnected, .connecting, .waitingForSAML, .connected, .disconnecting]
            for s in states {
                vm.state = s
                try expectFalse(vm.isErrorState, "Expected false for \(s)")
            }
        }
    }

    describe("LogEntry") {
        it("has correct id and text") {
            let entry = LogEntry(id: 42, text: "test")
            try expect(entry.id, toBe: 42)
            try expect(entry.text, toBe: "test")
        }
    }
}
