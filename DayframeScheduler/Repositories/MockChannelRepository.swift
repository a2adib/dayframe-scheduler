import Foundation

/// Mock channel store: starts with Instagram, X and LinkedIn connected
/// (Instagram's token near expiry to exercise the Reconnect badge).
final class MockChannelRepository: ChannelRepository {
    private var channels: [Channel]

    init(channels: [Channel] = MockData.channels) {
        self.channels = channels
    }

    func loadChannels() async throws -> [Channel] {
        channels
    }

    func connect(_ platform: Platform) async throws -> Channel {
        let channel = Channel(
            id: UUID(),
            platform: platform,
            externalAccountID: "mock-\(platform.rawValue)",
            handle: "@dayframe",
            displayName: platform.displayName,
            status: .connected,
            tokenExpiresAt: Calendar.current.date(byAdding: .day, value: 60, to: .now)
        )
        channels.append(channel)
        return channel
    }

    func reconnect(_ channel: Channel) async throws -> Channel {
        var updated = channel
        updated.status = .connected
        updated.tokenExpiresAt = Calendar.current.date(byAdding: .day, value: 60, to: .now)
        channels = channels.map { $0.id == channel.id ? updated : $0 }
        return updated
    }

    func disconnect(_ channel: Channel) async throws {
        channels.removeAll { $0.id == channel.id }
    }
}
