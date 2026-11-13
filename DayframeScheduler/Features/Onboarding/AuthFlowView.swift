import SwiftUI

/// Post-auth entry: routes to Connect Channels when the user has no channels,
/// otherwise straight to the Queue (AppFLOW 2.1 step 4).
struct AuthFlowView: View {
    var onFinished: () -> Void

    @State private var route: Route = .onboarding
    @State private var connectedChannelCount = 0

    enum Route {
        case onboarding
        case auth
        case connectChannels
    }

    var body: some View {
        Group {
            switch route {
            case .onboarding:
                OnboardingView { route = .auth }
            case .auth:
                AuthView {
                    // Phase 2 mock: pretend the account has no channels yet.
                    if connectedChannelCount == 0 {
                        route = .connectChannels
                    } else {
                        onFinished()
                    }
                }
            case .connectChannels:
                ConnectChannelsView(onFinished: onFinished)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: route)
    }
}

#Preview("AuthFlow") {
    AuthFlowView(onFinished: {})
}
