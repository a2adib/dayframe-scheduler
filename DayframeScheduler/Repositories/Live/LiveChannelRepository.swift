import Foundation
import Supabase

/// Response body of the oauth-start Edge Function.
struct OAuthStartResponse: Decodable {
    let url: String
}

struct LiveChannelRepository: ChannelRepository {
    let client: SupabaseClient

    func loadChannels() async throws -> [Channel] {
        let session = try await client.auth.session
        let rows: [ChannelRow] = try await client
            .from("channels_public")
            .select()
            .eq("user_id", value: session.user.id)
            .execute()
            .value
        return rows.map { row in
            Channel(
                id: row.id,
                platform: RowMapping.platform(row.platform),
                externalAccountID: row.externalAccountId,
                handle: row.handle ?? "",
                displayName: row.displayName ?? "",
                status: RowMapping.channelStatus(row.status),
                tokenExpiresAt: row.tokenExpiresAt
            )
        }
    }

    /// Runs the full OAuth flow: oauth-start returns the provider authorize
    /// URL, the in-app web session completes at the dayframe:// callback, and
    /// the refreshed channel row is reloaded from the database.
    func connect(_ platform: Platform) async throws -> Channel {
        try await runOAuth(platform: platform)
    }

    func reconnect(_ channel: Channel) async throws -> Channel {
        try await runOAuth(platform: channel.platform)
    }

    private func runOAuth(platform: Platform) async throws -> Channel {
        let start: OAuthStartResponse
        do {
            start = try await client.functions.invoke(
                "oauth-start",
                options: FunctionInvokeOptions(body: ["platform": platform.rawValue])
            )
        } catch let error as FunctionsError {
            throw AppError.oauth(error.errorDescription ?? "Could not start the \(platform.displayName) sign-in.")
        }
        guard let url = URL(string: start.url) else {
            throw AppError.oauth("The \(platform.displayName) sign-in URL was invalid.")
        }

        let callback = try await OAuthSessionService.make().run(authorizeURL: url)
        guard callback.status == "success" else {
            if callback.message == "cancelled" { throw AppError.oauthCancelled }
            throw AppError.oauth(callback.message ?? "\(platform.displayName) sign-in failed.")
        }

        let channels = try await loadChannels()
        guard let channel = channels.last(where: { $0.platform == platform }) else {
            throw AppError.oauth("\(platform.displayName) connected, but the channel was not found.")
        }
        return channel
    }

    func disconnect(_ channel: Channel) async throws {
        try await client
            .from("channels")
            .delete()
            .eq("id", value: channel.id)
            .execute()
    }
}
