import SwiftUI

/// The main popover view displayed from the menu bar icon.
struct MenuBarView: View {
    @EnvironmentObject var vpnManager: VPNManager
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            statusSection
            Divider()
            logSection
            Divider()
            footerSection
        }
        .frame(width: Constants.UI.popoverWidth, height: Constants.UI.popoverHeight)
        .alert(L10n.Sudoers.alertTitle, isPresented: $vpnManager.showSudoersAlert) {
            Button(L10n.Sudoers.install) {
                vpnManager.installSudoers()
            }
            Button(L10n.Sudoers.cancel, role: .cancel) {}
        } message: {
            Text(L10n.Sudoers.alertMessage)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Image(systemName: Constants.Symbols.appIcon)
                .font(.title2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(Constants.UI.appDisplayName)
                    .font(.headline)
                Text(vpnManager.settings.normalizedHost)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, Constants.UI.sectionPaddingH)
        .padding(.vertical, Constants.UI.sectionPaddingV)
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack {
            statusIndicator
            VStack(alignment: .leading, spacing: 2) {
                Text(vpnManager.state.localizedDescription)
                    .font(.subheadline.weight(.medium))
                if let date = vpnManager.connectionDate, vpnManager.state == .connected {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            connectionButton
        }
        .padding(.horizontal, Constants.UI.sectionPaddingH)
        .padding(.vertical, Constants.UI.sectionPaddingV)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: Constants.UI.statusIndicatorSize, height: Constants.UI.statusIndicatorSize)
            .overlay {
                if vpnManager.state == .connecting || vpnManager.state == .waitingForSAML || vpnManager.state == .disconnecting {
                    Circle()
                        .stroke(statusColor.opacity(0.5), lineWidth: 2)
                        .scaleEffect(1.5)
                        .opacity(0.8)
                }
            }
    }

    private var statusColor: Color {
        switch vpnManager.state {
        case .disconnected: return .secondary
        case .connecting, .waitingForSAML, .disconnecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }

    @ViewBuilder
    private var connectionButton: some View {
        if vpnManager.state.isActive {
            Button(action: { vpnManager.disconnect() }) {
                Text(L10n.Action.disconnect)
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .tint(.red)
        } else {
            Button(action: { vpnManager.connect() }) {
                Text(L10n.Action.connect)
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
    }

    // MARK: - Log

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L10n.Log.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { vpnManager.clearLog() }) {
                    Image(systemName: Constants.Symbols.trash)
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Constants.UI.sectionPaddingH)
            .padding(.top, Constants.UI.compactPaddingV)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(vpnManager.log) { entry in
                            Text(entry.text)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, Constants.UI.sectionPaddingH)
                }
                .onChange(of: vpnManager.logNextID) {
                    if let lastEntry = vpnManager.log.last {
                        withAnimation {
                            proxy.scrollTo(lastEntry.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Button(action: showSettings) {
                Image(systemName: Constants.Symbols.settings)
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button(L10n.Action.quit) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Constants.UI.sectionPaddingH)
        .padding(.vertical, Constants.UI.compactPaddingV)
    }

    /// Dismisses the popover and opens the SwiftUI Settings scene.
    ///
    /// Uses the `@Environment(\.openSettings)` action (macOS 14+) which is
    /// the only reliable way to open the `Settings` scene programmatically
    /// since Apple removed `sendAction(showSettingsWindow:)` in Sonoma.
    private func showSettings() {
        (NSApp.delegate as? AppDelegate)?.closePopover()
        openSettings()
        NSApp.activate(ignoringOtherApps: true)
    }
}
