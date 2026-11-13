import Foundation

/// Central runtime configuration for Dayframe.
/// Used to configure the backend connection whether running locally during development
/// or against a 24/7 Supabase Cloud project for real-life daily use.
enum AppConfig {
    /// Supabase backend URL.
    /// Priority:
    /// 1. Process environment variable `SUPABASE_URL` (Xcode debug schemes)
    /// 2. Info.plist `SUPABASE_URL` key
    /// 3. `defaultSupabaseURL`
    static var supabaseURL: URL {
        if let envUrl = ProcessInfo.processInfo.environment["SUPABASE_URL"],
           let url = URL(string: envUrl) {
            return url
        }
        if let plistUrl = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
           !plistUrl.isEmpty,
           let url = URL(string: plistUrl) {
            return url
        }
        return defaultSupabaseURL
    }

    /// Supabase Anon / Publishable Key.
    /// Priority:
    /// 1. Process environment variable `SUPABASE_ANON_KEY`
    /// 2. Info.plist `SUPABASE_ANON_KEY` key
    /// 3. `defaultSupabaseAnonKey`
    static var supabaseAnonKey: String {
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !envKey.isEmpty {
            return envKey
        }
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String, !plistKey.isEmpty {
            return plistKey
        }
        return defaultSupabaseAnonKey
    }

    /// Default Cloud project settings.
    /// When you create your free Supabase Cloud project at https://supabase.com,
    /// replace these values with your Project URL and Anon/Publishable Key.
    static let defaultSupabaseURL = URL(string: "http://127.0.0.1:54321")!
    static let defaultSupabaseAnonKey = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"

    /// Default backend mode for standalone app runs on device.
    /// Defaults to `.live` so the app connects to the real backend even when launched
    /// from the iPhone home screen untethered from Xcode.
    static var defaultBackendMode: AppEnvironment.BackendMode {
        if let envMode = ProcessInfo.processInfo.environment["DAYFRAME_BACKEND"],
           let mode = AppEnvironment.BackendMode(rawValue: envMode) {
            return mode
        }
        return .live
    }
}
