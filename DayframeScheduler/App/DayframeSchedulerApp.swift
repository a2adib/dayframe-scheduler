import SwiftUI

@main
struct DayframeSchedulerApp: App {
    var body: some Scene {
        WindowGroup {
            debugRoot
                .environment(AppEnvironment.shared)
        }
    }

    /// Debug hook: DAYFRAME_SCREEN=<name> forces a screen as root for
    /// simulator captures and future UI tests.
    private var debugRoot: some View {
        switch ProcessInfo.processInfo.environment["DAYFRAME_SCREEN"] {
        case "onboarding": AnyView(AuthFlowView(onFinished: {}))
        case "auth": AnyView(AuthView(onAuthenticated: {}))
        case "channels": AnyView(ConnectChannelsView(onFinished: {}))
        case "composer": AnyView(ComposerView(onSaved: {}))
        case "calendar": AnyView(NavigationStack { CalendarView() })
        case "analytics": AnyView(NavigationStack { AnalyticsView() })
        case "profile": AnyView(NavigationStack { ProfileView() })
        case "postdetail": AnyView(NavigationStack { PostDetailView(
            post: MockData.posts()[1],
            platforms: [.linkedin],
            onDeleted: {}, onRescheduled: { _ in }
        ) })
        default: AnyView(MainTabView())
        }
    }
}
