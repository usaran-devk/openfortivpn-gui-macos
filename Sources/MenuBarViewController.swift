import AppKit
import Combine

/// AppKit replacement for the former SwiftUI `MenuBarView`.
///
/// Builds the popover content view programmatically (no Interface Builder,
/// no SwiftUI) and keeps itself in sync with `VPNManager` via Combine
/// subscriptions on its `@Published` properties.
final class MenuBarViewController: NSViewController {
    private let vpnManager: VPNManager
    private var cancellables = Set<AnyCancellable>()

    /// Called when the user clicks the settings (gear) button.
    var onOpenSettings: (() -> Void)?

    // Header
    private let hostLabel = NSTextField(labelWithString: "")

    // Status
    private let statusIndicator = StatusIndicatorView()
    private let stateLabel = NSTextField(labelWithString: "")
    private let connectedSinceLabel = NSTextField(labelWithString: "")
    private let connectionButton = NSButton(title: "", target: nil, action: nil)

    // Log
    private let logTextView = NSTextView()
    private let logScrollView = NSScrollView()

    init(vpnManager: VPNManager) {
        self.vpnManager = vpnManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: Constants.UI.popoverWidth, height: Constants.UI.popoverHeight))
        view.wantsLayer = true
        buildLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }

    // MARK: - Layout

    private func buildLayout() {
        let header = makeHeaderSection()
        let status = makeStatusSection()
        let log = makeLogSection()
        let footer = makeFooterSection()

        let stack = NSStackView(views: [
            header,
            NSBox.divider(),
            status,
            NSBox.divider(),
            log,
            NSBox.divider(),
            footer,
        ])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor),
            log.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func makeHeaderSection() -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: Constants.Symbols.appIcon, accessibilityDescription: nil)
        icon.contentTintColor = .secondaryLabelColor
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)

        let titleLabel = NSTextField(labelWithString: Constants.UI.appDisplayName)
        titleLabel.font = .boldSystemFont(ofSize: 13)

        hostLabel.font = .systemFont(ofSize: 11)
        hostLabel.textColor = .secondaryLabelColor

        let textStack = NSStackView(views: [titleLabel, hostLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        let versionLabel = NSTextField(labelWithString: Self.appVersionString)
        versionLabel.font = .systemFont(ofSize: 10)
        versionLabel.textColor = .secondaryLabelColor

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [icon, textStack, spacer, versionLabel])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(
            top: Constants.UI.sectionPaddingV,
            left: Constants.UI.sectionPaddingH,
            bottom: Constants.UI.sectionPaddingV,
            right: Constants.UI.sectionPaddingH
        )
        return stack
    }

    private func makeStatusSection() -> NSView {
        statusIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusIndicator.widthAnchor.constraint(equalToConstant: Constants.UI.statusIndicatorSize),
            statusIndicator.heightAnchor.constraint(equalToConstant: Constants.UI.statusIndicatorSize),
        ])

        stateLabel.font = .systemFont(ofSize: 12, weight: .medium)
        connectedSinceLabel.font = .systemFont(ofSize: 10)
        connectedSinceLabel.textColor = .secondaryLabelColor

        let textStack = NSStackView(views: [stateLabel, connectedSinceLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        connectionButton.bezelStyle = .rounded
        connectionButton.target = self
        connectionButton.action = #selector(connectionButtonTapped)

        return row(leading: [statusIndicator, textStack], trailing: [connectionButton], h: Constants.UI.sectionPaddingH, v: Constants.UI.sectionPaddingV)
    }

    private func makeLogSection() -> NSView {
        let titleLabel = NSTextField(labelWithString: L10n.Log.title)
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor

        let clearButton = NSButton(image: NSImage(systemSymbolName: Constants.Symbols.trash, accessibilityDescription: nil) ?? NSImage(), target: self, action: #selector(clearLogTapped))
        clearButton.isBordered = false
        clearButton.bezelStyle = .inline
        clearButton.contentTintColor = .secondaryLabelColor

        let header = row(leading: [titleLabel], trailing: [clearButton], h: Constants.UI.sectionPaddingH, v: Constants.UI.compactPaddingV)

        logTextView.isEditable = false
        logTextView.isSelectable = true
        logTextView.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        logTextView.textColor = .secondaryLabelColor
        logTextView.drawsBackground = false
        logTextView.textContainerInset = NSSize(width: Constants.UI.sectionPaddingH, height: 4)

        logScrollView.documentView = logTextView
        logScrollView.hasVerticalScroller = true
        logScrollView.drawsBackground = false
        logScrollView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [header, logScrollView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0

        let logHeight = Constants.UI.popoverHeight
            - 2 * (Constants.UI.sectionPaddingV * 2)
            - Constants.UI.compactPaddingV * 2
            - 90
        NSLayoutConstraint.activate([
            logScrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            logScrollView.heightAnchor.constraint(equalToConstant: max(logHeight, 80)),
        ])
        return stack
    }

    private func makeFooterSection() -> NSView {
        let settingsButton = NSButton(title: L10n.Action.settings, target: self, action: #selector(settingsTapped))

        let quitButton = NSButton(title: L10n.Action.quit, target: self, action: #selector(quitTapped))

        let footer = NSStackView(views: [settingsButton, quitButton])
        footer.orientation = .horizontal
        footer.distribution = .fillEqually
        footer.spacing = 8
        footer.edgeInsets = NSEdgeInsets(
            top: Constants.UI.compactPaddingV,
            left: Constants.UI.sectionPaddingH,
            bottom: Constants.UI.sectionPaddingV,
            right: Constants.UI.sectionPaddingH
        )
        footer.translatesAutoresizingMaskIntoConstraints = false
        return footer
    }

    /// Builds a horizontal row with leading views, a flexible spacer, and trailing views.
    ///
    /// The spacer has no intrinsic content size, so the stack view's `.fill`
    /// distribution stretches it to push `trailing` views to the right edge.
    private func row(leading: [NSView], trailing: [NSView], h: CGFloat, v: CGFloat) -> NSView {
        var arranged = leading
        if !trailing.isEmpty {
            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            arranged.append(spacer)
            arranged.append(contentsOf: trailing)
        }

        let stack = NSStackView(views: arranged)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.distribution = .fill
        stack.edgeInsets = NSEdgeInsets(top: v, left: h, bottom: v, right: h)
        return stack
    }

    // MARK: - Bindings

    private func bindViewModel() {
        hostLabel.stringValue = vpnManager.settings.normalizedHost

        vpnManager.$settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] settings in
                self?.hostLabel.stringValue = settings.normalizedHost
            }
            .store(in: &cancellables)

        vpnManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateStatus(for: state)
            }
            .store(in: &cancellables)

        vpnManager.$log
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entries in
                self?.updateLog(entries)
            }
            .store(in: &cancellables)

        vpnManager.$showSudoersAlert
            .receive(on: DispatchQueue.main)
            .filter { $0 }
            .sink { [weak self] _ in
                self?.presentSudoersAlert()
            }
            .store(in: &cancellables)

        updateStatus(for: vpnManager.state)
        updateLog(vpnManager.log)
    }

    private func updateStatus(for state: VPNState) {
        stateLabel.stringValue = state.localizedDescription

        switch state {
        case .disconnected:
            statusIndicator.color = .secondaryLabelColor
            statusIndicator.isPulsing = false
        case .connecting, .waitingForSAML, .disconnecting:
            statusIndicator.color = .systemOrange
            statusIndicator.isPulsing = true
        case .connected:
            statusIndicator.color = .systemGreen
            statusIndicator.isPulsing = false
        case .error:
            statusIndicator.color = .systemRed
            statusIndicator.isPulsing = false
        }

        if state == .connected, let date = vpnManager.connectionDate {
            connectedSinceLabel.stringValue = Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
            connectedSinceLabel.isHidden = false
        } else {
            connectedSinceLabel.isHidden = true
        }

        if state.isActive {
            connectionButton.setProminentTitle(L10n.Action.disconnect, color: .systemRed)
        } else {
            connectionButton.setProminentTitle(L10n.Action.connect, color: .controlAccentColor)
        }
    }

    private func updateLog(_ entries: [LogEntry]) {
        logTextView.string = entries.map(\.text).joined(separator: "\n")
        logTextView.scrollToEndOfDocument(nil)
    }

    private func presentSudoersAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.Sudoers.alertTitle
        alert.informativeText = L10n.Sudoers.alertMessage
        alert.addButton(withTitle: L10n.Sudoers.install)
        alert.addButton(withTitle: L10n.Sudoers.cancel)

        let response = alert.runModal()
        vpnManager.showSudoersAlert = false
        if response == .alertFirstButtonReturn {
            vpnManager.installSudoers()
        }
    }

    // MARK: - Actions

    @objc private func connectionButtonTapped() {
        if vpnManager.state.isActive {
            vpnManager.disconnect()
        } else {
            vpnManager.connect()
        }
    }

    @objc private func clearLogTapped() {
        vpnManager.clearLog()
    }

    @objc private func settingsTapped() {
        onOpenSettings?()
    }

    @objc private func quitTapped() {
        NSApplication.shared.terminate(nil)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// The app's short version string (e.g. "v1.0.0"), read from `Info.plist`.
    private static var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        return "v\(version)"
    }
}

private extension NSBox {
    /// A thin horizontal divider line, matching SwiftUI's `Divider()`.
    static func divider() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}
