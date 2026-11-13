import Foundation
import Supabase

/// Live auth against Supabase (email + password; Apple/Google via OAuth).
struct LiveAuthService: AuthService {
    let client: SupabaseClient

    var currentUser: AuthUser? {
        get async {
            guard let session = try? await client.auth.session else { return nil }
            return AuthUser(id: session.user.id, email: session.user.email ?? "")
        }
    }

    func signUp(email: String, password: String) async throws -> AuthUser {
        do {
            let response = try await client.auth.signUp(email: email, password: password)
            return AuthUser(id: response.user.id, email: response.user.email ?? email)
        } catch {
            throw AuthError.invalidCredentials(friendly(error))
        }
    }

    func signIn(email: String, password: String) async throws -> AuthUser {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return AuthUser(id: session.user.id, email: session.user.email ?? email)
        } catch {
            throw AuthError.invalidCredentials(friendly(error))
        }
    }

    func signInWithOAuth(provider: OAuthProvider) async throws -> AuthUser {
        do {
            let session = try await client.auth.signInWithOAuth(
                provider: Provider(rawValue: provider.rawValue) ?? .apple
            )
            return AuthUser(id: session.user.id, email: session.user.email ?? "")
        } catch {
            throw AuthError.oauthUnavailable(
                "\(provider.rawValue.capitalized) sign-in isn't configured yet. Use email for now."
            )
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Deleting the auth user requires the service-role key and runs server-side;
    /// the client can only clear local data. The Edge Function lands in Phase 8.
    func deleteAccount() async throws {
        try await signOut()
    }

    private func friendly(_ error: Error) -> String {
        let message = error.localizedDescription
        if message.contains("Invalid login") || message.contains("invalid") {
            return "Email or password is incorrect."
        }
        if message.contains("already registered") {
            return "That email already has an account. Try signing in."
        }
        if message.contains("password") {
            return "Password must be at least 6 characters."
        }
        return message
    }
}
