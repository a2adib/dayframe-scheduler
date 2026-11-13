import Foundation

protocol ChannelRepository {
    func loadChannels() async throws -> [Channel]
    func connect(_ platform: Platform) async throws -> Channel
    func reconnect(_ channel: Channel) async throws -> Channel
    func disconnect(_ channel: Channel) async throws
}
