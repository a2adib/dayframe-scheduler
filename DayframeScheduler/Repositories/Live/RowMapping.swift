import Foundation
import Supabase

/// Codable row shapes for the Supabase schema (snake_case handled by the
/// client's JSON encoder/decoder configuration).
struct ProfileRow: Codable {
    var id: UUID
    var displayName: String?
    var avatarUrl: String?
    var timezone: String
    var theme: String
    var plan: String
}

struct ChannelRow: Codable {
    var id: UUID
    var userId: UUID
    var platform: String
    var externalAccountId: String
    var handle: String?
    var displayName: String?
    var status: String
    var tokenExpiresAt: Date?
}

struct PostRow: Codable {
    var id: UUID
    var userId: UUID
    var body: String
    var status: String
    var scheduleMode: String?
    var scheduledAt: Date?
    var publishedAt: Date?
}

struct PostTargetRow: Codable {
    var id: UUID
    var postId: UUID
    var userId: UUID
    var channelId: UUID
    var bodyOverride: String?
    var status: String
    var scheduledAt: Date?
}

struct MediaAssetRow: Codable {
    var id: UUID
    var userId: UUID
    var postId: UUID?
    var storagePath: String
    var kind: String
    var width: Int?
    var height: Int?
    var durationMs: Int?
    var position: Int
}

struct PostingSlotRow: Codable {
    var id: UUID
    var userId: UUID
    var channelId: UUID?
    var weekday: Int
    var localTime: String
    var active: Bool
}

struct MetricsDailyRow: Codable {
    var id: UUID
    var channelId: UUID
    var userId: UUID
    var day: String
    var followers: Int?
    var reach: Int?
    var engagement: Int?
    var clicks: Int?
}

enum RowMapping {
    static func platform(_ raw: String) -> Platform {
        Platform(rawValue: raw) ?? .x
    }

    static func postStatus(_ raw: String) -> PostStatus {
        PostStatus(rawValue: raw) ?? .draft
    }

    static func scheduleMode(_ raw: String?) -> ScheduleMode? {
        raw.flatMap(ScheduleMode.init(rawValue:))
    }

    static func channelStatus(_ raw: String) -> ChannelStatus {
        ChannelStatus(rawValue: raw) ?? .connected
    }

    static func plan(_ raw: String) -> PlanTier {
        PlanTier(rawValue: raw) ?? .free
    }

    /// `posting_slots.local_time` arrives as "HH:MM:SS".
    static func minutesFromMidnight(_ time: String) -> Int {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return 9 * 60 }
        return parts[0] * 60 + parts[1]
    }
}
