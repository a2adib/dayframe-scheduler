import Foundation
import Supabase

struct LiveIdeaRepository: IdeaRepository {
    let client: SupabaseClient

    func loadIdeas() async throws -> [Idea] {
        let session = try await client.auth.session
        let rows: [IdeaRow] = try await client
            .from("ideas")
            .select()
            .eq("user_id", value: session.user.id)
            .order("created_at", ascending: false)
            .execute()
            .value

        return rows.map { row in
            Idea(
                id: row.id,
                title: row.title,
                notes: row.notes,
                stage: RowMapping.ideaStage(row.stage),
                tags: row.tags,
                link: row.link,
                mediaURLs: row.mediaUrls ?? [],
                createdAt: row.createdAt,
                updatedAt: row.updatedAt
            )
        }
    }

    func saveIdea(_ idea: Idea) async throws -> Idea {
        let session = try await client.auth.session
        let row = IdeaRow(
            id: idea.id,
            userId: session.user.id,
            title: idea.title,
            notes: idea.notes,
            stage: idea.stage.rawValue,
            tags: idea.tags,
            link: idea.link,
            mediaUrls: idea.mediaURLs,
            createdAt: idea.createdAt,
            updatedAt: idea.updatedAt
        )

        let inserted: IdeaRow = try await client
            .from("ideas")
            .insert(row, returning: .representation)
            .single()
            .execute()
            .value

        return Idea(
            id: inserted.id,
            title: inserted.title,
            notes: inserted.notes,
            stage: RowMapping.ideaStage(inserted.stage),
            tags: inserted.tags,
            link: inserted.link,
            mediaURLs: inserted.mediaUrls ?? [],
            createdAt: inserted.createdAt,
            updatedAt: inserted.updatedAt
        )
    }

    func updateIdea(_ idea: Idea) async throws -> Idea {
        struct UpdateIdeaPayload: Codable {
            var title: String
            var notes: String
            var stage: String
            var tags: [String]
            var link: String?
            var updatedAt: String
        }

        let nowStr = SupabaseService.supabaseTimestampFormatter.string(from: .now)
        let payload = UpdateIdeaPayload(
            title: idea.title,
            notes: idea.notes,
            stage: idea.stage.rawValue,
            tags: idea.tags,
            link: idea.link,
            updatedAt: nowStr
        )

        try await client
            .from("ideas")
            .update(payload)
            .eq("id", value: idea.id)
            .execute()

        var updated = idea
        updated.updatedAt = .now
        return updated
    }

    func deleteIdea(_ idea: Idea) async throws {
        try await client
            .from("ideas")
            .delete()
            .eq("id", value: idea.id)
            .execute()
    }

    func moveStage(ideaID: UUID, to stage: IdeaStage) async throws -> Idea {
        let nowStr = SupabaseService.supabaseTimestampFormatter.string(from: .now)
        try await client
            .from("ideas")
            .update(["stage": stage.rawValue, "updated_at": nowStr])
            .eq("id", value: ideaID)
            .execute()

        let row: IdeaRow = try await client
            .from("ideas")
            .select()
            .eq("id", value: ideaID)
            .single()
            .execute()
            .value

        return Idea(
            id: row.id,
            title: row.title,
            notes: row.notes,
            stage: RowMapping.ideaStage(row.stage),
            tags: row.tags,
            link: row.link,
            mediaURLs: row.mediaUrls ?? [],
            createdAt: row.createdAt,
            updatedAt: row.updatedAt
        )
    }
}
