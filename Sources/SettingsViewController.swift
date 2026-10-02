import AppKit
import ServiceManagement

/// AppKit replacement for the former SwiftUI `SettingsView`.
///
/// Builds a simple form UI programmatically and validates input manually
/// via `NSTextFieldDelegate`, since this project avoids SwiftUI's
/// macro-based property wrappers (see docs/README.md).
final class SettingsViewController: NSViewController, NSTextFieldDelegate {
    private let vpnManager: VPNManager

    private let hostField = NSTextField()
    private let hostErrorLabel = NSTextField(labelWithString: "")
    private let portField = NSTextField()
    private let portErrorLabel = NSTextField(labelWithString: "")
    private let setDNSCheckbox = NSButton(checkboxWithTitle: L10n.Settings.setDNS, target: nil, action: nil)
    private let peerDNSCheckbox = NSButton(checkboxWithTitle: L10n.Settings.peerDNS, target: nil, action: nil)
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: L10n.Settings.launchAtLogin, target: nil, action: nil)
    private let saveButton = NSButton(title: L10n.Settings.save, target: nil, action: nil)

    init(vpnManager: VPNManager) {
        self.vpnManager = vpnManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: Constants.UI.settingsWidth, height: Constants.UI.settingsHeight))
        buildLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadSettings()
    }

    // MARK: - Layout

    private func buildLayout() {
        let connectionSection = section(title: L10n.Settings.connectionSection, content: [
            labeled(L10n.Settings.vpnHost, field: hostField),
            hostErrorLabel,
            labeled(L10n.Settings.samlPort, field: portField),
            portErrorLabel,
        ])

        let dnsFooter = NSTextField(wrappingLabelWithString: L10n.Settings.dnsFooter)
        dnsFooter.font = .systemFont(ofSize: 10)
        dnsFooter.textColor = .secondaryLabelColor

        let dnsSection = section(title: L10n.Settings.dnsSection, content: [
            setDNSCheckbox,
            peerDNSCheckbox,
            dnsFooter,
        ])

        let generalSection = section(title: L10n.Settings.generalSection, content: [
            launchAtLoginCheckbox,
        ])

        hostField.delegate = self
        portField.delegate = self
        hostErrorLabel.font = .systemFont(ofSize: 10)
        hostErrorLabel.textColor = .systemRed
        portErrorLabel.font = .systemFont(ofSize: 10)
        portErrorLabel.textColor = .systemRed

        let restoreButton = NSButton(title: L10n.Settings.restoreDefaults, target: self, action: #selector(restoreDefaultsTapped))
        let closeButton = NSButton(title: L10n.Action.close, target: self, action: #selector(closeTapped))

        saveButton.target = self
        saveButton.action = #selector(saveTapped)
        saveButton.keyEquivalent = "\r"
        saveButton.bezelStyle = .rounded

        let buttonRow = NSStackView(views: [restoreButton, NSView.spacer(), closeButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let stack = NSStackView(views: [connectionSection, dnsSection, generalSection, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let margin: CGFloat = 20
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: Constants.UI.settingsWidth),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -margin),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            connectionSection.widthAnchor.constraint(equalTo: stack.widthAnchor),
            dnsSection.widthAnchor.constraint(equalTo: stack.widthAnchor),
            generalSection.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func section(title: String, content: [NSView]) -> NSBox {
        let box = NSBox()
        box.boxType = .primary
        box.titlePosition = .atTop
        box.title = title
        box.titleFont = .systemFont(ofSize: 11, weight: .semibold)

        let inner = NSStackView(views: content)
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 6
        inner.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            inner.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            inner.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            inner.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
        ])
        box.contentView = contentView
        return box
    }

    private func labeled(_ title: String, field: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.widthAnchor.constraint(equalToConstant: 90).isActive = true

        field.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [label, field])
        stack.orientation = .horizontal
        stack.spacing = 8
        return stack
    }

    // MARK: - Data

    private func loadSettings() {
        hostField.stringValue = vpnManager.settings.vpnHost
        portField.stringValue = "\(vpnManager.settings.samlPort)"
        setDNSCheckbox.state = vpnManager.settings.setDNS ? .on : .off
        peerDNSCheckbox.state = vpnManager.settings.peerDNS ? .on : .off
        launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginTapped)
        validateHost()
        validatePort()
    }

    @discardableResult
    private func validateHost() -> Bool {
        let trimmed = hostField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        hostErrorLabel.stringValue = trimmed.isEmpty ? L10n.Settings.hostRequired : ""
        updateSaveButtonState()
        return trimmed.isEmpty == false
    }

    @discardableResult
    private func validatePort() -> Bool {
        if let port = Int(portField.stringValue),
           port >= Constants.Network.portMin,
           port <= Constants.Network.portMax {
            portErrorLabel.stringValue = ""
            updateSaveButtonState()
            return true
        }
        portErrorLabel.stringValue = L10n.Settings.invalidPort(Constants.Network.portMin, Constants.Network.portMax)
        updateSaveButtonState()
        return false
    }

    private func updateSaveButtonState() {
        saveButton.isEnabled = hostErrorLabel.stringValue.isEmpty && portErrorLabel.stringValue.isEmpty
    }

    // MARK: - Actions

    @objc private func saveTapped() {
        vpnManager.settings = VPNSettings(
            vpnHost: hostField.stringValue,
            samlPort: Int(portField.stringValue) ?? Constants.Defaults.samlPort,
            setDNS: setDNSCheckbox.state == .on,
            peerDNS: peerDNSCheckbox.state == .on
        )
        vpnManager.settings.save()
    }

    @objc private func closeTapped() {
        view.window?.close()
    }

    @objc private func restoreDefaultsTapped() {
        let defaults = VPNSettings.default
        hostField.stringValue = defaults.vpnHost
        portField.stringValue = "\(defaults.samlPort)"
        setDNSCheckbox.state = defaults.setDNS ? .on : .off
        peerDNSCheckbox.state = defaults.peerDNS ? .on : .off
        validateHost()
        validatePort()
    }

    /// Register or unregister the app as a login item via `SMAppService`.
    @objc private func launchAtLoginTapped() {
        let enabled = launchAtLoginCheckbox.state == .on
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("SettingsViewController: failed to \(enabled ? "register" : "unregister") login item: %@", error.localizedDescription)
            launchAtLoginCheckbox.state = SMAppService.mainApp.status == .enabled ? .on : .off
        }
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField else { return }
        if field === hostField {
            validateHost()
        } else if field === portField {
            validatePort()
        }
    }
}

/// Window controller that owns and lazily presents the settings window.
final class SettingsWindowController: NSWindowController {
    convenience init(vpnManager: VPNManager) {
        let viewController = SettingsViewController(vpnManager: vpnManager)
        let window = NSWindow(contentViewController: viewController)
        window.title = L10n.Settings.title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false

        // Size the window to fit its content exactly, since translated
        // strings (e.g. German) can wrap to more lines than the fixed
        // Constants.UI.settingsHeight anticipates, which previously clipped
        // the button row at the bottom.
        //
        // The window is intentionally not resizable: the form's content has
        // a fixed width constraint, so allowing a user to drag it narrower
        // would make the content overflow past the window's clipped edges.
        viewController.view.layoutSubtreeIfNeeded()
        let fittingSize = viewController.view.fittingSize
        window.setContentSize(NSSize(
            width: Constants.UI.settingsWidth,
            height: max(fittingSize.height, Constants.UI.settingsHeight)
        ))

        self.init(window: window)
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private extension NSView {
    /// A view with no intrinsic size, used to push sibling stack-view items apart.
    static func spacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }
}
