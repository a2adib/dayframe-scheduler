import Foundation

/// Raw values match the `ideas.stage` check constraint in the database.
enum IdeaStage: String, Codable, CaseIterable, Identifiable {
    case raw
    case drafting
    case ready
    case converted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .raw: "Raw Ideas"
        case .drafting: "Drafting"
        case .ready: "Ready to Schedule"
        case .converted: "Converted"
        }
    }

    var systemImage: String {
        switch self {
        case .raw: "lightbulb.fill"
        case .drafting: "square.and.pencil"
        case .ready: "checkmark.seal.fill"
        case .converted: "paperplane.fill"
        }
    }
}

struct Idea: Identifiable, Equatable, Codable {
    var id: UUID
    var title: String
    var notes: String
    var stage: IdeaStage
    var tags: [String]
    var link: String?
    var mediaURLs: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        stage: IdeaStage = .raw,
        tags: [String] = [],
        link: String? = nil,
        mediaURLs: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.stage = stage
        self.tags = tags
        self.link = link
        self.mediaURLs = mediaURLs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
