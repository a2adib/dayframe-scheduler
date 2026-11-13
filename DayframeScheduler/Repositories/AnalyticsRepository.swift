import Foundation

struct ChannelPostCount: Identifiable, Equatable {
    var platform: Platform
    var count: Int
    var id: Platform { platform }
}

protocol AnalyticsRepository {
    /// Daily aggregates across the requested number of days.
    func loadDailyMetrics(days: Int) async throws -> [DailyMetrics]
    func loadTopPosts(days: Int, limit: Int) async throws -> [TopPost]
    /// Published-post counts per platform for the bar chart.
    func loadPublishedPerChannel(days: Int) async throws -> [ChannelPostCount]
}
