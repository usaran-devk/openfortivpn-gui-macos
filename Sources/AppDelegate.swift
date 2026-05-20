import AppKit
import SwiftUI

/// Application delegate that sets up the menu bar icon and popover.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let vpnManager = VPNManager()

    // Menu bar SF Symbols are sized via symbol configuration, not image.size.
    private let statusIconConfiguration = NSImage.SymbolConfiguration(
        pointSize: 15,
        weight: .regular,
        scale: .medium
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only – hide from Dock
        NSApp.setActivationPolicy(.accessory)
        setupMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Ensure openfortivpn is stopped when the app quits
        if vpnManager.state.isActive {
            vpnManager.terminateImmediately()
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: 22)

        if let button = statusItem.button {
            button.imageScaling = .scaleProportionallyUpOrDown
            button.image = makeStatusIcon(named: Constants.Symbols.shieldDefault)
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: Constants.UI.popoverWidth, height: Constants.UI.popoverHeight)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenuBarView().environmentObject(vpnManager)
        )

        // Update icon based on VPN state
        Task {
            for await state in vpnManager.$state.values {
                updateIcon(for: state)
            }
        }
    }

    private func updateIcon(for state: VPNState) {
        let symbolName: String
        switch state {
        case .disconnected:   symbolName = Constants.Symbols.shieldDefault
        case .connecting:     symbolName = Constants.Symbols.shieldDefault
        case .waitingForSAML: symbolName = Constants.Symbols.shieldSAML
        case .connected:      symbolName = Constants.Symbols.shieldConnected
        case .disconnecting:  symbolName = Constants.Symbols.shieldDefault
        case .error:          symbolName = Constants.Symbols.shieldError
        }

        statusItem.button?.image = makeStatusIcon(named: symbolName)
    }

    private func makeStatusIcon(named symbolName: String) -> NSImage? {
        let baseImage = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: L10n.MenuBar.label
        )
        let configuredImage = baseImage?.withSymbolConfiguration(statusIconConfiguration) ?? baseImage
        configuredImage?.isTemplate = true
        return configuredImage
    }

    /// Closes the popover so the Settings window can appear unobstructed.
    func closePopover() {
        popover.performClose(nil)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
