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
    @State private var isSignUp = false

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
                    title: isSigningIn
                        ? (isSignUp ? "Creating account…" : "Signing in…")
                        : (isSignUp ? "Create account" : "Sign in"),
                    action: submit
                )
                .padding(.horizontal, DayframeSpacing.xl)

                Button(action: {
                    isSignUp.toggle()
                    errorMessage = nil
                }) {
                    Text(isSignUp ? "Already have an account? Sign in" : "Don't have an account? Sign up")
                        .font(DayframeFont.caption)
                        .foregroundStyle(DayframeColor.primary)
                }
                .padding(.top, DayframeSpacing.xs)

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

    private func submit() {
        Task {
            await authenticate {
                if isSignUp {
                    _ = try await environment.signUp(email: email, password: password)
                } else {
                    _ = try await environment.signIn(email: email, password: password)
                }
            }
        }
    }

    private func oauth(_ provider: OAuthProvider) async {
        errorMessage = nil
        isSigningIn = true
        defer { isSigningIn = false }
        do {
            _ = try await environment.signInWithOAuth(provider: provider)
            onAuthenticated()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func authenticate(_ operation: () async throws -> Void) async {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty || trimmedPassword.isEmpty {
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
