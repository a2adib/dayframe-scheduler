import Foundation
import Supabase

/// Configures and owns the Supabase client. URLs and keys come from the
/// environment (see .env.example); local defaults point at `supabase start`.
enum SupabaseService {
    static func makeClient(
        url: String = env("SUPABASE_URL", default: "http://127.0.0.1:54321"),
        key: String = env("SUPABASE_ANON_KEY", default: "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH")
    ) -> SupabaseClient {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom(decodeSupabaseDate)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(supabaseTimestampFormatter.string(from: date))
        }
        return SupabaseClient(
            supabaseURL: URL(string: url)!,
            supabaseKey: key,
            options: SupabaseClientOptions(db: .init(encoder: encoder, decoder: decoder))
        )
    }

    nonisolated(unsafe) static let supabaseTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) static let wholeSecondFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Supabase timestamptz may omit fractional seconds.
    static let decodeSupabaseDate: @Sendable (any Decoder) throws -> Date = { decoder in
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let date = supabaseTimestampFormatter.date(from: raw) {
            return date
        }
        if let date = wholeSecondFormatter.date(from: raw) {
            return date
        }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unparseable date: \(raw)")
    }

    private static func env(_ name: String, default defaultValue: String) -> String {
        ProcessInfo.processInfo.environment[name] ?? defaultValue
    }
}
