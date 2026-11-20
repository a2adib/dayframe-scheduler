import Foundation
import Supabase

struct LiveEngagementRepository: EngagementRepository {
    let client: SupabaseClient

    func loadItems() async throws -> [EngagementItem] {
        let session = try await client.auth.session
        let rows: [EngagementItemRow] = try await client
            .from("engagement_items")
            .select()
            .eq("user_id", value: session.user.id)
            .order("created_at", ascending: false)
            .execute()
            .value

        return rows.map { row in
            EngagementItem(
                id: row.id,
                channelID: row.channelId,
                postID: row.postId,
                postSnippet: nil,
                authorName: row.authorName,
                authorHandle: row.authorHandle ?? "",
                authorAvatarURL: row.authorAvatarUrl,
                content: row.content,
                platform: RowMapping.platform(row.platform),
                isReplied: row.isReplied,
                isStarred: row.isStarred,
                replyText: row.replyText,
                repliedAt: row.repliedAt,
                createdAt: row.createdAt
            )
        }
    }

    private struct ReplyPayload: Encodable {
        let is_replied: Bool
        let reply_text: String
        let replied_at: String
    }

    private struct StarPayload: Encodable {
        let is_starred: Bool
    }

    private struct MarkRepliedPayload: Encodable {
        let is_replied: Bool
        let reply_text: String?
        let replied_at: String?
    }

    func sendReply(itemID: UUID, replyText: String) async throws -> EngagementItem {
        let nowStr = SupabaseService.supabaseTimestampFormatter.string(from: .now)
        let payload = ReplyPayload(
            is_replied: true,
            reply_text: replyText,
            replied_at: nowStr
        )
        let row: EngagementItemRow = try await client
            .from("engagement_items")
            .update(payload)
            .eq("id", value: itemID)
            .single()
            .execute()
            .value

        return EngagementItem(
            id: row.id,
            channelID: row.channelId,
            postID: row.postId,
            authorName: row.authorName,
            authorHandle: row.authorHandle ?? "",
            authorAvatarURL: row.authorAvatarUrl,
            content: row.content,
            platform: RowMapping.platform(row.platform),
            isReplied: row.isReplied,
            isStarred: row.isStarred,
            replyText: row.replyText,
            repliedAt: row.repliedAt,
            createdAt: row.createdAt
        )
    }

    func toggleStar(itemID: UUID) async throws -> EngagementItem {
        let current: EngagementItemRow = try await client
            .from("engagement_items")
            .select()
            .eq("id", value: itemID)
            .single()
            .execute()
            .value

        let row: EngagementItemRow = try await client
            .from("engagement_items")
            .update(StarPayload(is_starred: !current.isStarred))
            .eq("id", value: itemID)
            .single()
            .execute()
            .value

        return EngagementItem(
            id: row.id,
            channelID: row.channelId,
            postID: row.postId,
            authorName: row.authorName,
            authorHandle: row.authorHandle ?? "",
            authorAvatarURL: row.authorAvatarUrl,
            content: row.content,
            platform: RowMapping.platform(row.platform),
            isReplied: row.isReplied,
            isStarred: row.isStarred,
            replyText: row.replyText,
            repliedAt: row.repliedAt,
            createdAt: row.createdAt
        )
    }

    private struct MarkRepliedOnlyPayload: Encodable {
        let is_replied: Bool
        let replied_at: String?
    }

    private struct ClearRepliedPayload: Encodable {
        let is_replied: Bool
        let reply_text: String?
        let replied_at: String?
    }

    func markReplied(itemID: UUID, isReplied: Bool) async throws -> EngagementItem {
        let row: EngagementItemRow
        if isReplied {
            let nowStr = SupabaseService.supabaseTimestampFormatter.string(from: .now)
            let payload = MarkRepliedOnlyPayload(is_replied: true, replied_at: nowStr)
            row = try await client
                .from("engagement_items")
                .update(payload)
                .eq("id", value: itemID)
                .single()
                .execute()
                .value
        } else {
            let payload = ClearRepliedPayload(is_replied: false, reply_text: nil, replied_at: nil)
            row = try await client
                .from("engagement_items")
                .update(payload)
                .eq("id", value: itemID)
                .single()
                .execute()
                .value
        }

        return EngagementItem(
            id: row.id,
            channelID: row.channelId,
            postID: row.postId,
            authorName: row.authorName,
            authorHandle: row.authorHandle ?? "",
            authorAvatarURL: row.authorAvatarUrl,
            content: row.content,
            platform: RowMapping.platform(row.platform),
            isReplied: row.isReplied,
            isStarred: row.isStarred,
            replyText: row.replyText,
            repliedAt: row.repliedAt,
            createdAt: row.createdAt
        )
    }
}
