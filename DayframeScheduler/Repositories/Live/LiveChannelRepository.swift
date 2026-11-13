import Foundation
import Supabase

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

    /// Connecting runs through oauth-start/oauth-callback Edge Functions in
    /// Phase 5; until then the live repository cannot create channels.
    func connect(_ platform: Platform) async throws -> Channel {
        throw AppError.notSupported(
            "\(platform.displayName) connection arrives with the OAuth Edge Functions (Phase 5)."
        )
    }

    func reconnect(_ channel: Channel) async throws -> Channel {
        try await client
            .from("channels")
            .update([
                "status": "connected",
                "token_expires_at": SupabaseService.supabaseTimestampFormatter.string(from: .now.addingTimeInterval(60 * 86_400)),
            ])
            .eq("id", value: channel.id)
            .execute()
        var updated = channel
        updated.status = .connected
        updated.tokenExpiresAt = .now.addingTimeInterval(60 * 86_400)
        return updated
    }

    func disconnect(_ channel: Channel) async throws {
        try await client
            .from("channels")
            .delete()
            .eq("id", value: channel.id)
            .execute()
    }
}
