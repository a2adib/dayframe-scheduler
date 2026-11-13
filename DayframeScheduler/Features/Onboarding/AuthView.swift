import SwiftUI

/// Auth screen: email + password, Continue with Apple, Continue with Google
/// (AppFLOW 2.1). Errors render inline under the fields.
struct AuthView: View {
    var onAuthenticated: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSigningIn = false

    var body: some View {
        VStack(spacing: DayframeSpacing.xl) {
            VStack(spacing: DayframeSpacing.lg) {
                DayframeLogoMark(size: 72)
                DayframeWordmark(size: 30)
            }
            .padding(.top, DayframeSpacing.xxl)

            VStack(alignment: .leading, spacing: DayframeSpacing.md) {
                field(title: "Email", text: $email)
                field(title: "Password", text: $password, isSecure: true)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color("Danger"))
                        .accessibilityLabel("Error: \(errorMessage)")
                }
            }
            .padding(.horizontal, DayframeSpacing.xl)

            VStack(spacing: DayframeSpacing.md) {
                PrimaryButton(
                    title: isSigningIn ? "Signing in…" : "Sign in",
                    action: signIn
                )
                .padding(.horizontal, DayframeSpacing.xl)

                socialButton(
                    title: "Continue with Apple",
                    systemImage: "apple.logo",
                    action: { Task { await oauth(.apple) } }
                )
                socialButton(
                    title: "Continue with Google",
                    systemImage: "g.circle",
                    action: { Task { await oauth(.google) } }
                )
            }
            .padding(.horizontal, DayframeSpacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(DayframeColor.background)
    }

    private func field(title: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
            Text(title)
                .font(DayframeFont.caption)
                .foregroundStyle(DayframeColor.textSecondary)
            Group {
                if isSecure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                }
            }
            .textFieldStyle(.plain)
            .padding(DayframeSpacing.md)
            .background(DayframeColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DayframeRadius.input, style: .continuous)
                    .strokeBorder(DayframeColor.border, lineWidth: 1)
            )
            .accessibilityLabel(title)
        }
    }

    private func socialButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DayframeSpacing.sm) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(DayframeFont.headline)
            .foregroundStyle(DayframeColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .overlay(Capsule().strokeBorder(DayframeColor.border, lineWidth: 1))
            .clipShape(Capsule())
        }
        .accessibilityLabel(title)
    }

    private func signIn() {
        Task { await authenticate { try await environment.signIn(email: email, password: password) } }
    }

    private func oauth(_ provider: OAuthProvider) async {
        await authenticate { _ = try await environment.authService.signInWithOAuth(provider: provider) }
    }

    private func authenticate(_ operation: () async throws -> Void) async {
        if email.isEmpty && password.isEmpty {
            errorMessage = "Enter your email and password to continue."
            return
        }
        errorMessage = nil
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            try await operation()
            onAuthenticated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("Auth") {
    AuthView(onAuthenticated: {})
}

#Preview("Auth dark") {
    AuthView(onAuthenticated: {})
        .environment(\.colorScheme, .dark)
}
