import Foundation
import Supabase

enum AppError: LocalizedError {
    case notSupported(String)
    case network(String)
    case oauthCancelled
    case oauth(String)

    var errorDescription: String? {
        switch self {
        case .notSupported(let message), .network(let message), .oauth(let message):
            message
        case .oauthCancelled:
            nil
        }
    }
}

struct LivePostRepository: PostRepository {
    let client: SupabaseClient
    var cache: QueueCaching = SwiftDataQueueCache()

    func loadQueue() async throws -> [Post] {
        do {
            let posts = try await fetchQueue()
            cache.store(posts)
            return posts
        } catch {
            // Offline (AppFLOW §3): serve the cached queue read-only.
            return cache.load()
        }
    }

    private func fetchQueue() async throws -> [Post] {
        let session = try await client.auth.session
        let userID = session.user.id
        let postRows: [PostRow] = try await client
            .from("posts")
            .select()
            .eq("user_id", value: userID)
            .neq("status", value: "draft")
            .is("deleted_at", value: nil)
            .order("scheduled_at", ascending: true)
            .execute()
            .value
        let targets: [PostTargetRow] = try await client
            .from("post_targets")
            .select()
            .eq("user_id", value: userID)
            .neq("status", value: "draft")
            .order("scheduled_at", ascending: true)
            .execute()
            .value
        let media: [MediaAssetRow] = try await client
            .from("media_assets")
            .select()
            .eq("user_id", value: userID)
            .execute()
            .value

        return postRows
            .filter { $0.status != "draft" }
            .map { row in
                Post(
                    id: row.id,
                    body: row.body,
                    status: RowMapping.postStatus(row.status),
                    scheduleMode: RowMapping.scheduleMode(row.scheduleMode),
                    scheduledAt: row.scheduledAt,
                    publishedAt: row.publishedAt,
                    targets: targets.filter { $0.postId == row.id }.map(\.target),
                    media: media.filter { $0.postId == row.id }.map(\.asset)
                )
            }
    }

    func loadPosts(on date: Date) async throws -> [Post] {
        let calendar = Calendar.current
        return try await loadQueue().filter { post in
            calendar.isDate(post.scheduledAt ?? .distantPast, inSameDayAs: date)
        }
    }

    func loadDrafts() async throws -> [Post] {
        let session = try await client.auth.session
        let rows: [PostRow] = try await client
            .from("posts")
            .select()
            .eq("user_id", value: session.user.id)
            .eq("status", value: "draft")
            .is("deleted_at", value: nil)
            .execute()
            .value
        return rows.map { row in
            Post(
                id: row.id, body: row.body, status: .draft, scheduleMode: nil,
                scheduledAt: nil, publishedAt: nil, targets: [], media: []
            )
        }
    }

    func save(
        _ post: Post,
        as status: PostStatus,
        scheduleMode: ScheduleMode?,
        scheduledAt: Date?
    ) async throws -> Post {
        let session = try await client.auth.session
        let userID = session.user.id
        let postRow = PostRow(
            id: post.id,
            userId: userID,
            body: post.body,
            status: status.rawValue,
            scheduleMode: scheduleMode?.rawValue,
            scheduledAt: scheduledAt,
            publishedAt: nil,
            // Unique (user_id, idempotency_key) makes scheduling retries safe.
            idempotencyKey: post.id.uuidString
        )
        let inserted: PostRow = try await client
            .from("posts")
            .insert(postRow, returning: .representation)
            .single()
            .execute()
            .value

        let targetRows = post.targets.map { target in
            PostTargetRow(
                id: target.id,
                postId: inserted.id,
                userId: userID,
                channelId: target.channelID,
                bodyOverride: target.bodyOverride,
                status: status.rawValue,
                scheduledAt: scheduledAt
            )
        }
        if !targetRows.isEmpty {
            try await client.from("post_targets").insert(targetRows).execute()
        }

        var saved = post
        saved.id = inserted.id
        saved.status = status
        saved.scheduleMode = scheduleMode
        saved.scheduledAt = scheduledAt
        saved.targets = post.targets.map { target in
            var t = target
            t.status = status
            t.scheduledAt = scheduledAt
            return t
        }
        return saved
    }

    func duplicate(_ post: Post) async throws -> Post {
        var copy = post
        copy.id = UUID()
        copy.targets = post.targets.map { var t = $0; t.id = UUID(); return t }
        copy.media = post.media.map { var m = $0; m.id = UUID(); return m }
        return try await save(copy, as: post.status, scheduleMode: post.scheduleMode, scheduledAt: post.scheduledAt)
    }

    func delete(_ post: Post) async throws {
        try await client
            .from("posts")
            .delete()
            .eq("id", value: post.id)
            .execute()
    }

    func reschedule(_ post: Post, to date: Date) async throws -> Post {
        try await client
            .from("posts")
            .update(["scheduled_at": SupabaseService.supabaseTimestampFormatter.string(from: date)])
            .eq("id", value: post.id)
            .execute()
        try await client
            .from("post_targets")
            .update(["scheduled_at": SupabaseService.supabaseTimestampFormatter.string(from: date)])
            .eq("post_id", value: post.id)
            .execute()
        var updated = post
        updated.scheduledAt = date
        updated.targets = post.targets.map { var t = $0; t.scheduledAt = date; return t }
        return updated
    }

    func attachMedia(_ data: Data, fileName: String, kind: MediaKind, to post: Post) async throws -> MediaAsset {
        let session = try await client.auth.session
        let userID = session.user.id
        let ext = (fileName as NSString).pathExtension
        let contentType: String
        switch ext.lowercased() {
        case "png": contentType = "image/png"
        case "mp4", "mov": contentType = "video/mp4"
        default: contentType = "image/jpeg"
        }
        // Storage policies require the first path segment to equal auth.uid()
        // (lowercase), so UUIDs are written in lowercase.
        let path = "\(userID.uuidString.lowercased())/\(post.id.uuidString.lowercased())/\(UUID().uuidString.lowercased()).\(ext.isEmpty ? "jpg" : ext)"
        try await client.storage.from("media").upload(
            path, data: data,
            options: FileOptions(contentType: contentType, upsert: false)
        )
        let row = MediaAssetRow(
            id: UUID(), userId: userID, postId: post.id, storagePath: path,
            kind: kind.rawValue, width: nil, height: nil, durationMs: nil, position: post.media.count
        )
        let inserted: MediaAssetRow = try await client
            .from("media_assets")
            .insert(row, returning: .representation)
            .single()
            .execute()
            .value
        return inserted.asset
    }
}

extension PostTargetRow {
    var target: PostTarget {
        PostTarget(
            id: id,
            channelID: channelId,
            bodyOverride: bodyOverride,
            status: RowMapping.postStatus(status),
            scheduledAt: scheduledAt,
            publishedAt: nil,
            attempts: 0,
            errorMessage: nil
        )
    }
}

extension MediaAssetRow {
    var asset: MediaAsset {
        MediaAsset(
            id: id,
            storagePath: storagePath,
            kind: MediaKind(rawValue: kind) ?? .image,
            width: width,
            height: height,
            durationMS: durationMs,
            position: position
        )
    }
}
