import AppKit

extension NSButton {
    /// Styles this button as a filled, accent-colored "prominent" button,
    /// equivalent to SwiftUI's `.buttonStyle(.borderedProminent)`.
    ///
    /// Sets `title` and restyles in one call, since `NSButton` doesn't retain
    /// a colored `attributedTitle` across plain `title` assignments.
    func setProminentTitle(_ title: String, color: NSColor = .controlAccentColor) {
        bezelStyle = .rounded
        isBordered = true
        bezelColor = color
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor.white,
                .font: font ?? .systemFont(ofSize: NSFont.systemFontSize),
            ]
        )
    }
}
