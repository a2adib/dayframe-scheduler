import Foundation

protocol AnalyticsRepository {
    /// Daily aggregates across the requested number of days.
    func loadDailyMetrics(days: Int) async throws -> [DailyMetrics]
    func loadTopPosts(days: Int, limit: Int) async throws -> [TopPost]
}
