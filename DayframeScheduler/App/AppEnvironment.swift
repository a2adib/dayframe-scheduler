import Foundation
import Observation
import SwiftUI

/// Dependency container injected through the environment (TRD.md §2).
/// The backend mode is a debug toggle: DAYFRAME_BACKEND=live selects the
/// Supabase-backed repositories; anything else uses mocks.
@Observable
final class AppEnvironment {
    private(set) var mode: BackendMode
    private(set) var authService: AuthService
    private(set) var profileRepository: ProfileRepository
    private(set) var channelRepository: ChannelRepository
    private(set) var postRepository: PostRepository
    private(set) var analyticsRepository: AnalyticsRepository
    private(set) var scheduleRepository: ScheduleRepository

    private(set) var currentUser: AuthUser?
    private(set) var currentProfile: Profile?

    var preferredColorScheme: ColorScheme? {
        switch currentProfile?.theme {
        case .light: return .light
        case .dark: return .dark
        case .system, .none: return nil
        }
    }

    enum BackendMode: String {
        case mock
        case live
    }

    init(mode: BackendMode = BackendMode(rawValue: ProcessInfo.processInfo.environment["DAYFRAME_BACKEND"] ?? "") ?? AppConfig.defaultBackendMode) {
        self.mode = mode
        switch mode {
        case .mock:
            authService = MockAuthService()
            profileRepository = MockProfileRepository()
            channelRepository = MockChannelRepository()
            postRepository = MockPostRepository()
            analyticsRepository = MockAnalyticsRepository()
            scheduleRepository = MockScheduleRepository()
        case .live:
            let client = SupabaseService.makeClient()
            authService = LiveAuthService(client: client)
            profileRepository = LiveProfileRepository(client: client)
            channelRepository = LiveChannelRepository(client: client)
            postRepository = LivePostRepository(client: client)
            analyticsRepository = LiveAnalyticsRepository(client: client)
            scheduleRepository = LiveScheduleRepository(client: client)
        }
    }

    func setBackendMode(_ newMode: BackendMode) async {
        guard newMode != mode else { return }
        UserDefaults.standard.set(newMode.rawValue, forKey: "dayframe_backend_mode")
        self.mode = newMode
        switch newMode {
        case .mock:
            self.authService = MockAuthService()
            self.profileRepository = MockProfileRepository()
            self.channelRepository = MockChannelRepository()
            self.postRepository = MockPostRepository()
            self.analyticsRepository = MockAnalyticsRepository()
            self.scheduleRepository = MockScheduleRepository()
        case .live:
            let client = SupabaseService.makeClient()
            self.authService = LiveAuthService(client: client)
            self.profileRepository = LiveProfileRepository(client: client)
            self.channelRepository = LiveChannelRepository(client: client)
            self.postRepository = LivePostRepository(client: client)
            self.analyticsRepository = LiveAnalyticsRepository(client: client)
            self.scheduleRepository = LiveScheduleRepository(client: client)
        }
        await restoreSession()
    }

    func restoreSession() async {
        currentUser = await authService.currentUser
        if currentUser != nil {
            await loadProfile()
        } else {
            currentProfile = nil
        }
    }

    func loadProfile() async {
        if let profile = try? await profileRepository.loadProfile() {
            currentProfile = profile
        }
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> AuthUser {
        currentUser = try await authService.signIn(email: email, password: password)
        await loadProfile()
        return currentUser!
    }

    @discardableResult
    func signUp(email: String, password: String) async throws -> AuthUser {
        currentUser = try await authService.signUp(email: email, password: password)
        await loadProfile()
        return currentUser!
    }

    @discardableResult
    func signInWithOAuth(provider: OAuthProvider) async throws -> AuthUser {
        let user = try await authService.signInWithOAuth(provider: provider)
        currentUser = user
        await loadProfile()
        return user
    }

    func signOut() async {
        try? await authService.signOut()
        currentUser = nil
        currentProfile = nil
    }
}

extension AppEnvironment {
    static let shared = AppEnvironment()
}
