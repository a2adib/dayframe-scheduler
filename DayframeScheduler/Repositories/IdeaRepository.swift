import Foundation

protocol IdeaRepository {
    func loadIdeas() async throws -> [Idea]
    func saveIdea(_ idea: Idea) async throws -> Idea
    func updateIdea(_ idea: Idea) async throws -> Idea
    func deleteIdea(_ idea: Idea) async throws
    func moveStage(ideaID: UUID, to stage: IdeaStage) async throws -> Idea
}
