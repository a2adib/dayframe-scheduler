import AuthenticationServices
import Foundation
import UIKit

/// Runs the provider OAuth in an in-app web session (AppFLOW 2.2): opens the
/// `oauth-start` URL and completes when the Edge Function bounces back to the
/// `dayframe://` scheme.
final class OAuthSessionService: NSObject, ASWebAuthenticationPresentationContextProviding {
    struct Callback: Equatable {
        let platform: Platform
        let status: String
        let message: String?
    }

    private static let cancelledCode = 1 // ASWebAuthenticationError.canceledLogin
    private static let errorDomain = "com.apple.AuthenticationServices.WebAuthenticationSession"

    private let anchor: ASPresentationAnchor
    private var session: ASWebAuthenticationSession?

    @MainActor
    static func make() -> OAuthSessionService {
        let anchor = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
        return OAuthSessionService(anchor: anchor)
    }

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    @MainActor
    func run(authorizeURL: URL) async throws -> Callback {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authorizeURL, callbackURLScheme: "dayframe") { [weak self] callbackURL, error in
                if let error {
                    let nsError = error as NSError
                    if nsError.domain == Self.errorDomain && nsError.code == Self.cancelledCode {
                        continuation.resume(throwing: AppError.oauthCancelled)
                    } else {
                        continuation.resume(throwing: AppError.oauth(error.localizedDescription))
                    }
                    return
                }
                guard let callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      components.host == "oauth",
                      let platformRaw = components.queryItems?.first(where: { $0.name == "platform" })?.value,
                      let platform = Platform(rawValue: platformRaw)
                else {
                    continuation.resume(throwing: AppError.oauth("Unexpected callback from the sign-in window."))
                    return
                }
                let status = components.queryItems?.first(where: { $0.name == "status" })?.value ?? "error"
                let message = components.queryItems?.first(where: { $0.name == "message" })?.value
                continuation.resume(returning: Callback(platform: platform, status: status, message: message))
                self?.session = nil
            }
            session.presentationContextProvider = self
            self.session = session
            session.start()
        }
    }

    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
