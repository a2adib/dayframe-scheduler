import Foundation
import SwiftData

/// SwiftData snapshot of a queue post for offline read-only access
/// (AppFLOW §3 offline behavior).
@Model
final class CachedPost {
    @Attribute(.unique) var postID: UUID
    var body: String
    var status: String
    var scheduledAt: Date?
    var platforms: [String]
    var mediaCaption: String?
    var cachedAt: Date

    init(
        postID: UUID,
        body: String,
        status: String,
        scheduledAt: Date?,
        platforms: [String],
        mediaCaption: String?,
        cachedAt: Date = .now
    ) {
        self.postID = postID
        self.body = body
        self.status = status
        self.scheduledAt = scheduledAt
        self.platforms = platforms
        self.mediaCaption = mediaCaption
        self.cachedAt = cachedAt
    }

    var post: Post {
        Post(
            id: postID,
            body: body,
            status: RowMapping.postStatus(status),
            scheduleMode: nil,
            scheduledAt: scheduledAt,
            publishedAt: nil,
            targets: [],
            media: []
        )
    }
}
