import Foundation

struct EngagementItem: Identifiable, Equatable, Codable {
    var id: UUID
    var channelID: UUID
    var postID: UUID?
    var postSnippet: String?
    var authorName: String
    var authorHandle: String
    var authorAvatarURL: String?
    var content: String
    var platform: Platform
    var isReplied: Bool
    var isStarred: Bool
    var replyText: String?
    var repliedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        channelID: UUID,
        postID: UUID? = nil,
        postSnippet: String? = nil,
        authorName: String,
        authorHandle: String,
        authorAvatarURL: String? = nil,
        content: String,
        platform: Platform,
        isReplied: Bool = false,
        isStarred: Bool = false,
        replyText: String? = nil,
        repliedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.channelID = channelID
        self.postID = postID
        self.postSnippet = postSnippet
        self.authorName = authorName
        self.authorHandle = authorHandle
        self.authorAvatarURL = authorAvatarURL
        self.content = content
        self.platform = platform
        self.isReplied = isReplied
        self.isStarred = isStarred
        self.replyText = replyText
        self.repliedAt = repliedAt
        self.createdAt = createdAt
    }
}
