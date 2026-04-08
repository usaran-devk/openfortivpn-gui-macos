import Foundation

/// Represents the current state of the VPN connection.
enum VPNState: Equatable, Sendable {
    case disconnected
    case connecting
    case waitingForSAML
    case connected
    case disconnecting
    case error(String)

    /// Localized display string for this state.
    var localizedDescription: String {
        switch self {
        case .disconnected: return L10n.State.disconnected
        case .connecting: return L10n.State.connecting
        case .waitingForSAML: return L10n.State.waitingForSAML
        case .connected: return L10n.State.connected
        case .disconnecting: return L10n.State.disconnecting
        case .error(let msg): return "\(L10n.State.error): \(msg)"
        }
    }

    /// Whether the VPN is in an active state (connecting or connected).
    var isActive: Bool {
        switch self {
        case .connecting, .waitingForSAML, .connected:
            return true
        default:
            return false
        }
    }
}
