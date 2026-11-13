import Foundation

struct Post: Identifiable, Equatable {
    var id: UUID
    var body: String
    var status: PostStatus
    var scheduleMode: ScheduleMode?
    var scheduledAt: Date?
    var publishedAt: Date?
    var targets: [PostTarget]
    var media: [MediaAsset]

    /// Derived status is stored on the post (Schema.md section 4); targets may
    /// differ per channel.
    var isMediaAttached: Bool { !media.isEmpty }
}
