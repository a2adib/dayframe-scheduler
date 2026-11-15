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
    /// Configured for your 24/7 Supabase Cloud project.
    static let defaultSupabaseURL = URL(string: "https://gllzmbwndzvaoonyerov.supabase.co")!
    static let defaultSupabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdsbHptYnduZHp2YW9vbnllcm92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ2NjYzMjUsImV4cCI6MjExMDI0MjMyNX0.BKAySseZ-CC4nbbTfIL-yWKnW_s8skFWWOyJXCOjdVo"

    /// Default backend mode for standalone app runs on device.
    /// Defaults to `.live` so real Supabase Cloud data, live OAuth channels,
    /// real posts, and live scheduling are used.
    static var defaultBackendMode: AppEnvironment.BackendMode {
        if let envMode = ProcessInfo.processInfo.environment["DAYFRAME_BACKEND"],
           let mode = AppEnvironment.BackendMode(rawValue: envMode) {
            return mode
        }
        if let savedMode = UserDefaults.standard.string(forKey: "dayframe_backend_mode"),
           let mode = AppEnvironment.BackendMode(rawValue: savedMode) {
            return mode
        }
        return .live
    }
}
