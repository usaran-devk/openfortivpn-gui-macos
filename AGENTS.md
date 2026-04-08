# Agent Instructions for openfortivpn-gui

## Build/Test/Lint Commands

**Build the app:**
```bash
make all
```

**Run the app:**
```bash
make run
```

**Run all tests:**
```bash
make test
```

**Run specific test suite:**
Edit `Tests/Tests.swift` (around line 74) and comment out the `test*()` function calls in `TestRunner.main()`, leaving only the one you want. Then:
```bash
make test
```
Available test suites: VPNState, VPNSettings, VPNSettings Edge Cases, VPNSettings Persistence, Localization, Localization Completeness, Localization Log Messages, Localization Sudoers Alert, PrivilegedExecution, VPNManager.* (handleOutput, handleTermination, appendLog, clearLog, isErrorState, LogEntry), Constants.* (Executables, Process, LogPatterns, Network, Defaults, StorageKeys, Sudoers, UI, Symbols)

**Verify build compiles:**
```bash
make all
```
(Builds the app bundle to `.build/OpenFortiVPN.app`)

**Clean build artifacts:**
```bash
make clean
```

**Install sudoers rule (allows passwordless VPN launch):**
```bash
make install-sudoers
```

**Full installation (build + sudoers + copy to /Applications):**
```bash
make install
```

**Uninstall:**
```bash
make uninstall
```

**Swift version:** 6 with `-O` optimization flag

## Code Style Guidelines

### Imports
- Use alphabetical order within categories (Foundation first, then AppKit/SwiftUI)
- Group related imports: standard library, then framework/library imports

### Naming Conventions
- **Types (classes, structs, enums):** PascalCase (e.g., `VPNManager`, `VPNState`)
- **Functions/properties/variables:** camelCase (e.g., `handleOutput`, `connectedSince`)
- **Constants:** camelCase in groups, or PascalCase for enum cases (e.g., `Constants.Executables.sudo`, `case .disconnected`)
- **Private properties:** prefix with underscore or mark `private`
- **Published properties (SwiftUI):** use `@Published` for observable state
- **Main Actor:** mark view controllers with `@MainActor` for UI thread safety

### Formatting & Structure
- **Line length:** No strict limit, but keep reasonable for readability
- **Indentation:** 4 spaces (not tabs)
- **Access modifiers:** Explicit (e.g., `private(set)`, `final` for classes)
- **MARK comments:** Use `// MARK: -` to organize sections within files
- **Blank lines:** One between methods, sections marked with MARK

### Documentation & Comments
- **Public APIs:** Document with `///` doc comments explaining purpose, parameters, returns, and edge cases
- **Complex logic:** Add inline comments explaining "why," not just "what"
- **Doc comment format:**
  ```swift
  /// Brief description.
  ///
  /// Longer explanation if needed.
  /// - Parameters:
  ///   - param1: Description.
  /// - Returns: Description.
  ```

### Types & Errors
- **Use optionals sparingly:** Prefer `Result<T, Error>` or explicit error states for failures
- **Equatable/Sendable:** Apply to types that need comparison or thread safety
- **Associated values in enums:** Use for context (e.g., `case error(String)`)
- **Error handling:** Throw `Error` types or use `Result`; avoid silent failures
- **Error types:** Define custom `Error` enums for specific error cases; log all errors before throwing

### Concurrency & Thread Safety
- **MainActor:** Mark SwiftUI views and view models with `@MainActor` for UI thread safety
- **Sendable:** Apply `Sendable` to types passed between threads (e.g., error states, process output)
- **Avoid data races:** Use `nonisolated(unsafe)` only for test globals; document the reason

### Constants & Magic Numbers
- **Centralize:** All hard-coded strings and numbers in `Sources/Constants.swift`
- **Organize by category:** Use nested enums (e.g., `Constants.Executables`, `Constants.LogPatterns`)
- **Document:** Add comments explaining purpose and usage

### Testing
- **Use custom test framework:** `Tests/Tests.swift` provides `describe()`, `it()`, `mainActorIt()`, and expectations
- **Testable sources:** Listed in Makefile `TESTABLE_SOURCES` (currently: Constants, Localization, VPNState, VPNSettings, PrivilegedExecution, VPNManager)
- **Exclude from tests:** UI files (MenuBarView, SettingsView, AppDelegate) and `@main` entry point
- **Expectations:** Use `expect()`, `expectTrue()`, `expectFalse()`, `expectNil()`, `expectNotNil()`, etc.
- **No interactive tests:** Avoid password prompts; mock/inject dependencies instead
- **Test isolation:** Each test should be independent; clean up shared state (e.g., UserDefaults) manually after each test

### i18n & Localization
- **Never hardcode user-facing strings:** Always use `L10n.* keys` (e.g., `L10n.State.connected`)
- **Provide German translations:** See `Sources/Localization.swift` for keys and translations
- **Organize keys:** Group by feature/context (e.g., `L10n.State.*`, `L10n.Error.*`, `L10n.Log.*`)

### Git Commits

1. Keep git commit messages short but meaningful

## Key Guidelines

1. Maintain a `./.gitignore` file
2. Maintain a `./README.md` file with a brief project overview
3. Maintain existing code structure and organisation.
4. Write unit tests for new functionality.
5. Use i18n and provide translations for German.
6. Document public APIs and complex logic.
7. Provide documentation about how to compile, install, uninstall and use the program.
8. Suggest changes to the `docs/` folder when appropriate.
9. Follow software principles such as DRY and YAGNI.
10. Keep diffs as minimal as possible.
11. Avoid interactive actions in tests (e.g., password entries for privilege escalation).
12. Avoid hardcoded strings; always use constants clustered in `Constants.swift`.

## Functional Guidelines

1. Make the VPN url and SAML proxy port configurable with the following defaults:
   1. VPN url: ""
   2. SAML proxy port: 8020
2. Persist all configureable options so that they are reused on the next application start
3. Ensure openfortivpn SAML proxy (`http://127.0.0.1:<port>`) is started before opening the browser.
4. Use `sudo` to start openfortivpn (requires sudoers NOPASSWD rule).
5. Ensure no interactive password entry is required for privileged operations. If unavoidable:
   - Show a warning message explaining the requirement.
   - Provide a function/UI to install sudoers rules from within the app.
6. Ensure the openfortivpn process terminates properly on VPN disconnect or app exit.
7. Use `PrivilegedExecution.run()` for launching privileged processes with output streaming.
8. Monitor process output via log patterns in `Constants.LogPatterns` to detect state changes.

## Packaging Guidelines

1. Design sudoers rules as drop-in files in `/etc/sudoers.d/`.
2. Use `make install-sudoers` to set up passwordless execution (prompts once for admin credentials).
3. Include uninstall rules to clean up sudoers files.

