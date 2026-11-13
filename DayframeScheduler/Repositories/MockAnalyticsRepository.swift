import Foundation

final class MockAnalyticsRepository: AnalyticsRepository {
    func loadDailyMetrics(days: Int) async throws -> [DailyMetrics] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        return (0..<days).flatMap { offset -> [DailyMetrics] in
            let day = calendar.date(byAdding: .day, value: -offset, to: start)!
            return MockData.channels.map { channel in
                let wave = sin(Double(offset) / 3.1 + Double(channel.platform.hashValue % 10))
                let reach = 400 + Int((wave + 1) * 180) + offset * 12
                return DailyMetrics(
                    channelID: channel.id,
                    day: day,
                    followers: 1200 + (30 - offset) * 3,
                    reach: reach,
                    engagement: reach / 12,
                    clicks: reach / 30
                )
            }
        }
    }

    func loadTopPosts(days: Int, limit: Int) async throws -> [TopPost] {
        Array(MockData.topPosts.prefix(limit))
    }

    func loadPublishedPerChannel(days: Int) async throws -> [ChannelPostCount] {
        MockData.channels.map { ChannelPostCount(platform: $0.platform, count: 3 + Int($0.platform.hashValue.magnitude % 5)) }
            .sorted { $0.count > $1.count }
    }
}
