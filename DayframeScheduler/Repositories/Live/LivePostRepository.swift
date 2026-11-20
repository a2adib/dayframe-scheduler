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
                    media: media.filter { $0.postId == row.id }.map(\.asset),
                    firstComment: row.firstComment
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
                scheduledAt: nil, publishedAt: nil, targets: [], media: [],
                firstComment: row.firstComment
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
            idempotencyKey: post.id.uuidString,
            firstComment: post.firstComment
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
                firstComment: target.firstComment ?? post.firstComment,
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

    /// Target statuses that must never be rewritten: the platform already has
    /// (or is receiving) this post, so resetting them would publish it twice.
    private static let lockedTargetStatuses: Set<String> = [
        PostStatus.published.rawValue, PostStatus.publishing.rawValue,
    ]

    private struct ExistingTargetRow: Decodable {
        let id: UUID
        let channelId: UUID
        let status: String
    }

    private static func json(_ value: String?) -> AnyJSON {
        value.map(AnyJSON.string) ?? .null
    }

    private static func json(_ date: Date?) -> AnyJSON {
        date.map { .string(SupabaseService.supabaseTimestampFormatter.string(from: $0)) } ?? .null
    }

    func update(
        _ post: Post,
        as status: PostStatus,
        scheduleMode: ScheduleMode?,
        scheduledAt: Date?
    ) async throws -> Post {
        let session = try await client.auth.session
        let userID = session.user.id

        let existing: [ExistingTargetRow] = try await client
            .from("post_targets")
            .select("id, channel_id, status")
            .eq("post_id", value: post.id)
            .execute()
            .value
        let lockedChannels = Set(
            existing.filter { Self.lockedTargetStatuses.contains($0.status) }.map(\.channelId)
        )
        let editableByChannel = Dictionary(
            existing.filter { !Self.lockedTargetStatuses.contains($0.status) }.map { ($0.channelId, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Explicit nulls so clearing a field (e.g. scheduled -> draft, removing
        // a first comment) actually clears the column.
        let postPayload: [String: AnyJSON] = [
            "body": .string(post.body),
            "status": .string(status.rawValue),
            "schedule_mode": Self.json(scheduleMode?.rawValue),
            "scheduled_at": Self.json(scheduledAt),
            "first_comment": Self.json(post.firstComment),
            "updated_at": Self.json(Date.now),
        ]
        try await client
            .from("posts")
            .update(postPayload)
            .eq("id", value: post.id)
            .execute()

        let wantedTargets = post.targets.filter { !lockedChannels.contains($0.channelID) }
        let wantedChannels = Set(wantedTargets.map(\.channelID))

        // Update editable targets in place (keeps their ids), insert new ones.
        var newRows: [PostTargetRow] = []
        for target in wantedTargets {
            if let row = editableByChannel[target.channelID] {
                let targetPayload: [String: AnyJSON] = [
                    "body_override": Self.json(target.bodyOverride),
                    "first_comment": Self.json(target.firstComment ?? post.firstComment),
                    "status": .string(status.rawValue),
                    "scheduled_at": Self.json(scheduledAt),
                    "attempts": .integer(0),
                    "next_attempt_at": .null,
                    "error_message": .null,
                ]
                try await client
                    .from("post_targets")
                    .update(targetPayload)
                    .eq("id", value: row.id)
                    .execute()
            } else {
                newRows.append(PostTargetRow(
                    id: target.id,
                    postId: post.id,
                    userId: userID,
                    channelId: target.channelID,
                    bodyOverride: target.bodyOverride,
                    firstComment: target.firstComment ?? post.firstComment,
                    status: status.rawValue,
                    scheduledAt: scheduledAt
                ))
            }
        }
        if !newRows.isEmpty {
            try await client.from("post_targets").insert(newRows).execute()
        }

        // Remove only editable targets for channels the user deselected.
        let removedIDs = editableByChannel.values
            .filter { !wantedChannels.contains($0.channelId) }
            .map { $0.id.uuidString }
        if !removedIDs.isEmpty {
            try await client
                .from("post_targets")
                .delete()
                .in("id", values: removedIDs)
                .execute()
        }

        var saved = post
        saved.status = status
        saved.scheduleMode = scheduleMode
        saved.scheduledAt = scheduledAt
        saved.targets = post.targets.map { target in
            guard !lockedChannels.contains(target.channelID) else { return target }
            var t = target
            t.status = status
            t.scheduledAt = scheduledAt
            return t
        }
        return saved
    }

    /// Re-queues only the targets that failed; published targets are left alone.
    func retry(_ post: Post) async throws -> Post {
        let now = Date.now
        let targetPayload: [String: AnyJSON] = [
            "status": .string(PostStatus.scheduled.rawValue),
            "scheduled_at": Self.json(now),
            "attempts": .integer(0),
            "next_attempt_at": .null,
            "error_message": .null,
        ]
        try await client
            .from("post_targets")
            .update(targetPayload)
            .eq("post_id", value: post.id)
            .eq("status", value: PostStatus.failed.rawValue)
            .execute()

        // The post's own status is derived from its targets by trigger.
        try await client
            .from("posts")
            .update(["scheduled_at": Self.json(now), "updated_at": Self.json(now)])
            .eq("id", value: post.id)
            .execute()

        var retried = post
        retried.status = .scheduled
        retried.scheduledAt = now
        retried.targets = post.targets.map { target in
            guard target.status == .failed else { return target }
            var t = target
            t.status = .scheduled
            t.scheduledAt = now
            t.attempts = 0
            t.errorMessage = nil
            return t
        }
        return retried
    }

    func duplicate(_ post: Post) async throws -> Post {
        var copy = post
        copy.id = UUID()
        copy.firstComment = post.firstComment
        let targetStatus: PostStatus = (post.status == .published || post.status == .publishing || post.status == .failed) ? .draft : post.status
        let targetMode: ScheduleMode? = targetStatus == .draft ? nil : post.scheduleMode
        let targetDate: Date? = targetStatus == .draft ? nil : post.scheduledAt
        copy.targets = post.targets.map {
            var t = $0
            t.id = UUID()
            t.status = targetStatus
            t.scheduledAt = targetDate
            t.publishedAt = nil
            t.attempts = 0
            t.errorMessage = nil
            return t
        }
        copy.media = post.media.map { var m = $0; m.id = UUID(); return m }
        return try await save(copy, as: targetStatus, scheduleMode: targetMode, scheduledAt: targetDate)
    }

    func reorderQueue(posts: [Post]) async throws {
        for post in posts {
            if let scheduledAt = post.scheduledAt {
                let scheduledAtStr = SupabaseService.supabaseTimestampFormatter.string(from: scheduledAt)
                try await client
                    .from("posts")
                    .update(["scheduled_at": scheduledAtStr])
                    .eq("id", value: post.id)
                    .execute()
                // Never move targets that already published or are in flight.
                try await client
                    .from("post_targets")
                    .update(["scheduled_at": scheduledAtStr])
                    .eq("post_id", value: post.id)
                    .eq("status", value: PostStatus.scheduled.rawValue)
                    .execute()
            }
        }
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
            firstComment: firstComment,
            status: RowMapping.postStatus(status),
            scheduledAt: scheduledAt,
            publishedAt: publishedAt,
            attempts: attempts ?? 0,
            errorMessage: errorMessage
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
