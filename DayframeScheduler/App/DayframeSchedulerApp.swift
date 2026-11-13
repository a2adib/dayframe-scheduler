import SwiftUI

@main
struct DayframeSchedulerApp: App {
    @State private var environment = AppEnvironment.shared
    @State private var authChecked = false

    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.environment["DAYFRAME_SCREEN"] != nil {
                    debugScreen
                } else if authChecked {
                    if environment.currentUser != nil {
                        MainTabView()
                    } else {
                        AuthFlowView(onAuthenticated: {})
                    }
                } else {
                    LaunchView()
                        .task {
                            // Defensive timeout: prevent network hangs from blocking app launch
                            await withTaskGroup(of: Void.self) { group in
                                group.addTask {
                                    await environment.restoreSession()
                                }
                                group.addTask {
                                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                                }
                                _ = await group.next()
                                group.cancelAll()
                            }
                            authChecked = true
                        }
                }
            }
            .environment(environment)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: authChecked)
        }
    }

    /// Debug hook: DAYFRAME_SCREEN=<name> forces a screen as root for
    /// simulator captures and future UI tests.
    @ViewBuilder
    private var debugScreen: some View {
        switch ProcessInfo.processInfo.environment["DAYFRAME_SCREEN"] {
        case "onboarding": AuthFlowView(onAuthenticated: {})
        case "auth": AuthView(onAuthenticated: {})
        case "channels": ConnectChannelsView(onFinished: {})
        case "composer": ComposerView(onSaved: {})
        case "calendar": NavigationStack { CalendarView() }
        case "analytics": NavigationStack { AnalyticsView() }
        case "profile": NavigationStack { ProfileView() }
        case "postdetail": NavigationStack { PostDetailView(
            post: MockData.posts()[1],
            platforms: [.linkedin],
            onDeleted: {}, onRescheduled: { _ in }
        ) }
        default: MainTabView()
        }
    }
}
