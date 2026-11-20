import SwiftUI

/// Post-auth entry: routes to Connect Channels when the user has no channels,
/// otherwise straight to the Queue (AppFLOW 2.1 step 4).
struct AuthFlowView: View {
    var onAuthenticated: () -> Void

    @Environment(AppEnvironment.self) private var environment
    @AppStorage("dayframe_has_completed_onboarding") private var hasCompletedOnboarding = false
    @State private var route: AuthFlowRoute = .onboarding
    @State private var channels: [Channel] = []
    @State private var initializedRoute = false

    enum Route {
        case onboarding
        case auth
        case connectChannels
    }

    var body: some View {
        Group {
            switch route {
            case .onboarding:
                OnboardingView {
                    hasCompletedOnboarding = true
                    route = .auth
                }
            case .auth:
                AuthView(onAuthenticated: { route = .postAuth })
            case .connectChannels:
                NavigationStack {
                    ConnectChannelsView(onFinished: { onAuthenticated() })
                }
            case .postAuth:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DayframeColor.background)
                    .task { await routeAfterAuth() }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: route)
        .onAppear {
            if !initializedRoute {
                initializedRoute = true
                if hasCompletedOnboarding {
                    route = .auth
                }
            }
        }
    }

    private enum AuthFlowRoute {
        case onboarding, auth, connectChannels, postAuth
    }

    private func routeAfterAuth() async {
        channels = (try? await environment.channelRepository.loadChannels()) ?? []
        if channels.isEmpty {
            route = .connectChannels
        } else {
            onAuthenticated()
        }
    }
}

#Preview("AuthFlow") {
    AuthFlowView(onAuthenticated: {})
}
