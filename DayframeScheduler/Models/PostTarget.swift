import Foundation

struct PostTarget: Identifiable, Equatable {
    var id: UUID
    var channelID: UUID
    var bodyOverride: String?
    var firstComment: String? = nil
    var status: PostStatus
    var scheduledAt: Date?
    var publishedAt: Date?
    var attempts: Int
    var errorMessage: String?
}
