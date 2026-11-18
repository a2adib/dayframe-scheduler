import SwiftUI

/// Notification toggles and theme selection (AppFLOW 2.8, F13).
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    var model: ProfileViewModel

    var body: some View {
        List {
            Section("Notifications") {
                toggle("Published posts", value: Binding(
                    get: { model.notifications.postPublished },
                    set: { model.setNotification(\.postPublished, to: $0) }
                ))
                toggle("Failed posts", value: Binding(
                    get: { model.notifications.postFailed },
                    set: { model.setNotification(\.postFailed, to: $0) }
                ))
                toggle("Weekly report", value: Binding(
                    get: { model.notifications.weeklyReport },
                    set: { model.setNotification(\.weeklyReport, to: $0) }
                ))
            }
            Section("Theme") {
                Picker("Theme", selection: Binding(
                    get: { model.profile?.theme ?? .system },
                    set: { newValue in
                        Task {
                            await model.setTheme(newValue)
                            await environment.loadProfile()
                        }
                    }
                )) {
                    Text("System").tag(Profile.Theme.system)
                    Text("Light").tag(Profile.Theme.light)
                    Text("Dark").tag(Profile.Theme.dark)
                }
                .tint(DayframeColor.primary)
            }
            Section("Backend Mode") {
                Picker("Backend Mode", selection: Binding(
                    get: { environment.mode },
                    set: { newMode in
                        Task {
                            await environment.setBackendMode(newMode)
                            await model.load()
                        }
                    }
                )) {
                    Text("Demo Mode").tag(AppEnvironment.BackendMode.mock)
                    Text("Live Cloud").tag(AppEnvironment.BackendMode.live)
                }
                .pickerStyle(.segmented)

                if environment.mode == .mock {
                    Text("Demo Mode provides pre-connected channels (Instagram, X, LinkedIn), sample scheduled posts, and metrics so all functions work immediately without developer API keys.")
                        .font(.caption)
                        .foregroundStyle(DayframeColor.textSecondary)
                } else {
                    Text("Live Cloud connects to Supabase. Requires OAuth Client IDs & Secrets configured in Supabase.")
                        .font(.caption)
                        .foregroundStyle(DayframeColor.textSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func toggle(_ title: String, value: Binding<Bool>) -> some View {
        Toggle(title, isOn: value)
            .tint(DayframeColor.primary)
    }
}

#Preview("Settings") {
    NavigationStack {
        SettingsView(model: ProfileViewModel(
            profileRepository: MockProfileRepository(),
            channelRepository: MockChannelRepository(),
            scheduleRepository: MockScheduleRepository()
        ))
    }
}
