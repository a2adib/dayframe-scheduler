import Foundation

/// Mock auth for the mock backend mode: any sign-in succeeds instantly.
final class MockAuthService: AuthService {
    var currentUser: AuthUser?

    func signUp(email: String, password: String) async throws -> AuthUser {
        let user = AuthUser(id: UUID(), email: email)
        currentUser = user
        return user
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        let user = AuthUser(id: MockData.profile.id, email: email)
        currentUser = user
        return user
    }

    func signInWithOAuth(provider: OAuthProvider) async throws -> AuthUser {
        let user = AuthUser(id: MockData.profile.id, email: "adib@dayframe.app")
        currentUser = user
        return user
    }

    func signOut() async throws {
        currentUser = nil
    }

    func deleteAccount() async throws {
        currentUser = nil
    }
}
