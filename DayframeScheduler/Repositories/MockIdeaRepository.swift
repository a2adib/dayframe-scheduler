import Foundation

final class MockIdeaRepository: IdeaRepository {
    private var ideas: [Idea]

    init(ideas: [Idea]? = nil) {
        if let ideas {
            self.ideas = ideas
        } else {
            self.ideas = [
                Idea(
                    id: UUID(),
                    title: "Why 90% of Creators Burn Out",
                    notes: "Break down the creator treadmill vs sustainable batching. Mention 3 systems that worked for us: timeboxing, batching on Mondays, and using Dayframe to queue 2 weeks out.",
                    stage: .raw,
                    tags: ["creator-economy", "mindset"],
                    link: "https://dayframe.app/blog/burnout",
                    mediaURLs: [],
                    createdAt: .now.addingTimeInterval(-86400 * 3)
                ),
                Idea(
                    id: UUID(),
                    title: "10 AI Tools that Save 10 Hours a Week",
                    notes: "Curated breakdown of high-leverage workflows: research assistant, hook generation, auto-resizing visuals, and first comment automation.",
                    stage: .drafting,
                    tags: ["ai", "productivity", "tips"],
                    link: nil,
                    mediaURLs: [],
                    createdAt: .now.addingTimeInterval(-86400 * 2)
                ),
                Idea(
                    id: UUID(),
                    title: "Behind the Scenes iOS 18 Widgets",
                    notes: "Show off our interactive queue and calendar lock-screen widgets in action. Clean screen recording + voiceover on swift animations.",
                    stage: .ready,
                    tags: ["ios", "buildinpublic", "swiftui"],
                    link: "https://x.com/dayframe",
                    mediaURLs: [],
                    createdAt: .now.addingTimeInterval(-86400 * 1)
                ),
                Idea(
                    id: UUID(),
                    title: "The Math Behind Organic Reach in 2026",
                    notes: "How algorithmic feeds prioritize saves and comments over vanity likes. Hook: 'Your reach didn't drop — your format did.'",
                    stage: .raw,
                    tags: ["growth", "algorithms"],
                    link: nil,
                    mediaURLs: [],
                    createdAt: .now.addingTimeInterval(-86400 * 4)
                )
            ]
        }
    }

    func loadIdeas() async throws -> [Idea] {
        ideas.sorted { $0.createdAt > $1.createdAt }
    }

    func saveIdea(_ idea: Idea) async throws -> Idea {
        var copy = idea
        if copy.id == UUID.init() || ideas.contains(where: { $0.id == copy.id }) {
            copy.id = UUID()
        }
        ideas.append(copy)
        return copy
    }

    func updateIdea(_ idea: Idea) async throws -> Idea {
        var copy = idea
        copy.updatedAt = .now
        ideas = ideas.map { $0.id == idea.id ? copy : $0 }
        return copy
    }

    func deleteIdea(_ idea: Idea) async throws {
        ideas.removeAll { $0.id == idea.id }
    }

    func moveStage(ideaID: UUID, to stage: IdeaStage) async throws -> Idea {
        guard let index = ideas.firstIndex(where: { $0.id == ideaID }) else {
            throw AppError.network("Idea not found")
        }
        var updated = ideas[index]
        updated.stage = stage
        updated.updatedAt = .now
        ideas[index] = updated
        return updated
    }
}
