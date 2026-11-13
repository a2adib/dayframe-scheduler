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
        let session = try await client.auth.session
        let since = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let sinceText = SupabaseService.supabaseTimestampFormatter.string(from: since)
        let rows: [TopPostMetricRow] = try await client
            .from("post_metrics")
            .select("reach,likes,comments,shares,post_targets!inner(id,posts(body),channels(platform))")
            .eq("user_id", value: session.user.id)
            .gte("post_targets.published_at", value: sinceText)
            .order("reach", ascending: false)
            .limit(limit)
            .execute()
            .value
        return rows.compactMap { row in
            guard let target = row.postTargets?.first,
                  let body = target.posts?.body,
                  let platformRaw = target.channels?.platform
            else { return nil }
            return TopPost(
                id: UUID(),
                body: body,
                platform: RowMapping.platform(platformRaw),
                reach: row.reach ?? 0,
                engagement: (row.likes ?? 0) + (row.comments ?? 0) + (row.shares ?? 0)
            )
        }
    }

    func loadPublishedPerChannel(days: Int) async throws -> [ChannelPostCount] {
        let session = try await client.auth.session
        let since = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let sinceText = SupabaseService.supabaseTimestampFormatter.string(from: since)
        let rows: [PublishedTargetRow] = try await client
            .from("post_targets")
            .select("id,channels(platform)")
            .eq("user_id", value: session.user.id)
            .eq("status", value: "published")
            .gte("published_at", value: sinceText)
            .execute()
            .value
        var counts: [Platform: Int] = [:]
        for row in rows {
            if let platformRaw = row.channels?.first?.platform {
                counts[RowMapping.platform(platformRaw), default: 0] += 1
            }
        }
        return counts.map { ChannelPostCount(platform: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

/// Row shapes for the nested PostgREST selects above.
private struct TopPostMetricRow: Codable {
    var reach: Int?
    var likes: Int?
    var comments: Int?
    var shares: Int?
    var postTargets: [PostTargetNested]?
}

private struct PostTargetNested: Codable {
    var posts: PostNested?
    var channels: ChannelNested?
}

private struct PostNested: Codable {
    var body: String
}

private struct ChannelNested: Codable {
    var platform: String
}

private struct PublishedTargetRow: Codable {
    var id: UUID
    var channels: [ChannelNested]?
}
