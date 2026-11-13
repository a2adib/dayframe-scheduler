import Foundation
import Observation

/// Dependency container injected through the environment (TRD.md §2).
/// The backend mode is a debug toggle: DAYFRAME_BACKEND=live selects the
/// Supabase-backed repositories; anything else uses mocks.
@Observable
final class AppEnvironment {
    let mode: BackendMode
    let authService: AuthService
    let profileRepository: ProfileRepository
    let channelRepository: ChannelRepository
    let postRepository: PostRepository
    let analyticsRepository: AnalyticsRepository
    let scheduleRepository: ScheduleRepository

    private(set) var currentUser: AuthUser?

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

    func restoreSession() async {
        currentUser = await authService.currentUser
    }

    @discardableResult
    func signIn(email: String, password: String) async throws -> AuthUser {
        currentUser = try await authService.signIn(email: email, password: password)
        return currentUser!
    }

    @discardableResult
    func signUp(email: String, password: String) async throws -> AuthUser {
        currentUser = try await authService.signUp(email: email, password: password)
        return currentUser!
    }

    func signOut() async {
        try? await authService.signOut()
        currentUser = nil
    }
}

extension AppEnvironment {
    static let shared = AppEnvironment()
}
