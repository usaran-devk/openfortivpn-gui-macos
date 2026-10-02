import AppKit

/// Application entry point.
///
/// Replaces the former SwiftUI `@main App` scene with a plain AppKit
/// bootstrap, since this project avoids SwiftUI's macro-based property
/// wrappers (see docs/README.md). `AppDelegate` still does all the work.
let appDelegate = AppDelegate()
let app = NSApplication.shared
app.delegate = appDelegate
app.run()
