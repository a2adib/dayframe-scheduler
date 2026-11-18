import Foundation
import Observation

@Observable
@MainActor
final class IdeasBoardViewModel {
    private let ideaRepository: IdeaRepository

    private(set) var ideas: [Idea] = []
    private(set) var isLoading = false
    private(set) var error: String?
    var selectedStage: IdeaStage = .raw
    var searchQuery = ""

    init(ideaRepository: IdeaRepository) {
        self.ideaRepository = ideaRepository
    }

    var filteredIdeas: [Idea] {
        ideas.filter { idea in
            let matchesStage = idea.stage == selectedStage
            if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
                return matchesStage
            }
            let query = searchQuery.lowercased()
            let matchesQuery = idea.title.lowercased().contains(query) ||
                idea.notes.lowercased().contains(query) ||
                idea.tags.contains { $0.lowercased().contains(query) }
            return matchesStage && matchesQuery
        }
    }

    func count(for stage: IdeaStage) -> Int {
        ideas.filter { $0.stage == stage }.count
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            ideas = try await ideaRepository.loadIdeas()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func addIdea(title: String, notes: String, stage: IdeaStage, tags: [String], link: String?) async {
        let newIdea = Idea(
            id: UUID(),
            title: title,
            notes: notes,
            stage: stage,
            tags: tags,
            link: link,
            mediaURLs: [],
            createdAt: .now,
            updatedAt: .now
        )
        if let saved = try? await ideaRepository.saveIdea(newIdea) {
            ideas.insert(saved, at: 0)
        }
    }

    func updateIdea(_ idea: Idea) async {
        if let updated = try? await ideaRepository.updateIdea(idea) {
            ideas = ideas.map { $0.id == idea.id ? updated : $0 }
        }
    }

    func deleteIdea(_ idea: Idea) async {
        try? await ideaRepository.deleteIdea(idea)
        ideas.removeAll { $0.id == idea.id }
    }

    func advanceStage(for idea: Idea) async {
        let nextStage: IdeaStage?
        switch idea.stage {
        case .raw: nextStage = .drafting
        case .drafting: nextStage = .ready
        case .ready: nextStage = .converted
        case .converted: nextStage = nil
        }
        guard let next = nextStage else { return }
        if let updated = try? await ideaRepository.moveStage(ideaID: idea.id, to: next) {
            ideas = ideas.map { $0.id == idea.id ? updated : $0 }
        }
    }

    func moveToStage(idea: Idea, to stage: IdeaStage) async {
        if let updated = try? await ideaRepository.moveStage(ideaID: idea.id, to: stage) {
            ideas = ideas.map { $0.id == idea.id ? updated : $0 }
        }
    }
}
