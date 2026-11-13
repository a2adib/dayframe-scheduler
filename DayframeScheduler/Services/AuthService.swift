import Foundation

struct AuthUser: Equatable {
    var id: UUID
    var email: String
}

protocol AuthService {
    var currentUser: AuthUser? { get async }

    func signUp(email: String, password: String) async throws -> AuthUser
    func signIn(email: String, password: String) async throws -> AuthUser
    /// Continue with Apple / Google via OAuth (in-app web flow server-side).
    func signInWithOAuth(provider: OAuthProvider) async throws -> AuthUser
    func signOut() async throws
    /// Deletes the account server-side (Phase 8 wires the Edge Function).
    func deleteAccount() async throws
}

enum OAuthProvider: String {
    case apple
    case google
}

enum AuthError: LocalizedError {
    case invalidCredentials(String)
    case oauthUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials(let message), .oauthUnavailable(let message):
            message
        }
    }
}
