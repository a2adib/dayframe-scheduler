import Foundation
import Supabase

struct LiveAnalyticsRepository: AnalyticsRepository {
    let client: SupabaseClient

    func loadDailyMetrics(days: Int) async throws -> [DailyMetrics] {
        let session = try await client.auth.session
        let since = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let sinceText = String(ISO8601DateFormatter().string(from: since).prefix(10))
        let rows: [MetricsDailyRow] = try await client
            .from("metrics_daily")
            .select()
            .eq("user_id", value: session.user.id)
            .gte("day", value: sinceText)
            .execute()
            .value
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        return rows.compactMap { row in
            guard let day = dayFormatter.date(from: row.day) else { return nil }
            return DailyMetrics(
                channelID: row.channelId,
                day: day,
                followers: row.followers ?? 0,
                reach: row.reach ?? 0,
                engagement: row.engagement ?? 0,
                clicks: row.clicks ?? 0
            )
        }
    }

    func loadTopPosts(days: Int, limit: Int) async throws -> [TopPost] {
        // Top posts come from post_metrics joined with posts; the metrics
        // tables fill via refresh-metrics in Phase 6, so empty for now.
        []
    }
}
