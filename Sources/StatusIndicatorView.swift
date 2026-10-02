import AppKit

/// A small filled circle used to indicate VPN connection status, with an
/// optional pulsing ring overlay for transitional states.
///
/// Replaces the SwiftUI `Circle().overlay { ... }` indicator so the menu
/// bar UI can be built with AppKit only (no SwiftUI macro plugin required).
final class StatusIndicatorView: NSView {
    var color: NSColor = .secondaryLabelColor {
        didSet { needsDisplay = true }
    }

    var isPulsing: Bool = false {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let inset: CGFloat = isPulsing ? bounds.width * 0.15 : 0
        let dotRect = bounds.insetBy(dx: inset, dy: inset)

        if isPulsing {
            let ringColor = color.withAlphaComponent(0.5)
            let ringPath = NSBezierPath(ovalIn: bounds)
            ringPath.lineWidth = 2
            ringColor.setStroke()
            ringPath.stroke()
        }

        let dotPath = NSBezierPath(ovalIn: dotRect)
        color.setFill()
        dotPath.fill()
    }
}
