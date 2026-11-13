import Foundation

struct Channel: Identifiable, Equatable {
    var id: UUID
    var platform: Platform
    var externalAccountID: String
    var handle: String
    var displayName: String
    var status: ChannelStatus
    var tokenExpiresAt: Date?
}
