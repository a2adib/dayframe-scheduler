import Foundation

enum ConnectionHealth: String, Codable, CaseIterable {
    case connected = "Connected"
    case needsReauth = "Needs Reauth"
    case paused = "Paused"

    var systemImage: String {
        switch self {
        case .connected: "checkmark.circle.fill"
        case .needsReauth: "exclamationmark.triangle.fill"
        case .paused: "pause.circle.fill"
        }
    }
}

struct Channel: Identifiable, Equatable {
    var id: UUID
    var platform: Platform
    var externalAccountID: String
    var handle: String
    var displayName: String
    var status: ChannelStatus
    var isPaused: Bool = false
    var tokenExpiresAt: Date?

    var connectionHealth: ConnectionHealth {
        if isPaused { return .paused }
        switch status {
        case .connected:
            if let expiry = tokenExpiresAt, expiry < .now {
                return .needsReauth
            }
            return .connected
        case .expired, .revoked:
            return .needsReauth
        }
    }
}
