import Foundation
import Supabase

struct LiveProfileRepository: ProfileRepository {
    let client: SupabaseClient

    func loadProfile() async throws -> Profile {
        let session = try await client.auth.session
        let row: ProfileRow = try await client
            .from("profiles")
            .select()
            .eq("id", value: session.user.id)
            .single()
            .execute()
            .value
        return Profile(
            id: row.id,
            displayName: row.displayName ?? session.user.email ?? "You",
            avatarURL: row.avatarUrl.flatMap(URL.init(string:)),
            timezone: row.timezone,
            theme: Profile.Theme(rawValue: row.theme) ?? .system,
            plan: RowMapping.plan(row.plan)
        )
    }

    func updateTheme(_ theme: Profile.Theme) async throws {
        let session = try await client.auth.session
        try await client
            .from("profiles")
            .update(["theme": theme.rawValue])
            .eq("id", value: session.user.id)
            .execute()
    }

    func logout() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount() async throws {
        try await client.auth.signOut()
    }
}
