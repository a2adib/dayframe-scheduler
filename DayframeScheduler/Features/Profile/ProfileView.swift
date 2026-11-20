import SwiftUI

/// Profile and settings (AppFLOW 2.8, UI_Spec §4.8): user header, channels,
/// posting schedule editor, notifications, theme, upgrade card, About,
/// logout, delete account. No Figma frame; UI_Spec defaults.
struct ProfileView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: ProfileViewModel?
    @State private var showsDeleteConfirmation = false
    @State private var showsProSheet = false
    @State private var deleteError: String?

    var body: some View {
        Group {
            if let model {
                content(model: model)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DayframeColor.background)
        .navigationTitle("Profile")
        .onAppear {
            if let model {
                Task { await model.load() }
            }
        }
        .task {
            if model == nil {
                let viewModel = ProfileViewModel(
                    profileRepository: environment.profileRepository,
                    channelRepository: environment.channelRepository,
                    scheduleRepository: environment.scheduleRepository
                )
                model = viewModel
                await viewModel.load()
            }
        }
        .sheet(isPresented: $showsProSheet) {
            VStack(spacing: DayframeSpacing.lg) {
                DayframeLogoMark(size: 56)
                Text("Dayframe Pro")
                    .font(DayframeFont.largeTitle(24))
                    .foregroundStyle(DayframeColor.textPrimary)
                Text("Unlock 90-day analytics, unlimited channels, and unlimited scheduled posts.")
                    .font(DayframeFont.body)
                    .foregroundStyle(DayframeColor.textSecondary)
                    .multilineTextAlignment(.center)
                Text("In-app upgrades aren't available yet.")
                    .font(DayframeFont.caption)
                    .foregroundStyle(DayframeColor.textSecondary)
                PrimaryButton(title: "Got it") {
                    showsProSheet = false
                }
            }
            .padding(DayframeSpacing.xl)
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func content(model: ProfileViewModel) -> some View {
        List {
            if let profile = model.profile {
                header(profile: profile)
            }
            channelsSection(model: model)
            scheduleSection(model: model)
            settingsSection(model: model)
            planSection(model: model)
            accountSection(model: model)
        }
        .listStyle(.insetGrouped)
        .confirmationDialog(
            "Delete your account?",
            isPresented: Binding(
                get: { model.showsDeleteConfirmation },
                set: { model.showsDeleteConfirmation = $0 }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                Task {
                    do {
                        try await environment.deleteAccount()
                    } catch {
                        deleteError = error.localizedDescription
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your data and revokes all connected tokens. This cannot be undone.")
        }
        .alert(
            "Couldn't delete your account",
            isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func header(profile: Profile) -> some View {
        HStack(spacing: DayframeSpacing.lg) {
            Circle()
                .fill(DayframeColor.brandGradient)
                .frame(width: 64, height: 64)
                .overlay(
                    Text(String(profile.displayName.prefix(1)))
                        .font(DayframeFont.largeTitle(24))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                Text(profile.displayName)
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.textPrimary)
                HStack(spacing: DayframeSpacing.sm) {
                    Text(profile.plan == .pro ? "Pro" : "Free plan")
                        .font(DayframeFont.caption)
                        .foregroundStyle(profile.plan == .pro ? DayframeColor.primary : DayframeColor.textSecondary)
                    if profile.plan == .pro {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(DayframeColor.primary)
                    }
                }
            }
            Spacer()
        }
        .padding(.vertical, DayframeSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private func channelsSection(model: ProfileViewModel) -> some View {
        Section("Connected Channels") {
            ForEach(model.channels) { channel in
                HStack(spacing: DayframeSpacing.md) {
                    ChannelAvatar(platform: channel.platform, size: 36)
                    Text(channel.platform.displayName)
                        .font(DayframeFont.headline)
                        .foregroundStyle(DayframeColor.textPrimary)
                    Spacer()
                    if channel.status == .expired {
                        Text("Reconnect")
                            .font(DayframeFont.caption)
                            .foregroundStyle(Color("Warning"))
                    }
                    Text(channel.handle)
                        .font(.system(size: 13))
                        .foregroundStyle(DayframeColor.textSecondary)
                }
            }
            NavigationLink {
                ConnectChannelsView(onFinished: {}, showsDoneButton: false)
            } label: {
                Label("Add channels", systemImage: "plus.circle")
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.primary)
            }
            .accessibilityLabel("Add channels")
        }
    }

    private func scheduleSection(model: ProfileViewModel) -> some View {
        Section("Posting Schedule") {
            NavigationLink {
                PostingScheduleView(model: model)
            } label: {
                Label("Edit posting schedule", systemImage: "calendar.badge.clock")
                    .foregroundStyle(DayframeColor.textPrimary)
            }
            .accessibilityLabel("Edit posting schedule")
        }
    }

    private func settingsSection(model: ProfileViewModel) -> some View {
        Section("Settings") {
            NavigationLink {
                SettingsView(model: model)
            } label: {
                Label("Notifications & theme", systemImage: "bell")
                    .foregroundStyle(DayframeColor.textPrimary)
            }
            .accessibilityLabel("Notifications and theme settings")
        }
    }

    private func planSection(model: ProfileViewModel) -> some View {
        Section {
            Button {
                showsProSheet = true
            } label: {
                HStack(spacing: DayframeSpacing.md) {
                    DayframeLogoMark(size: 40)
                        .opacity(0.5)
                    VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                        Text(model.profile?.plan == .pro ? "Pro Plan Active" : "Upgrade to Pro")
                            .font(DayframeFont.headline)
                            .foregroundStyle(DayframeColor.textPrimary)
                        Text("Unlimited channels, scheduled posts, and 90-day analytics.")
                            .font(.system(size: 13))
                            .foregroundStyle(DayframeColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DayframeColor.textTertiary)
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(DayframeColor.background)
        } header: {
            Text("Subscription")
        }
    }

    private func accountSection(model: ProfileViewModel) -> some View {
        Section {
            Button {
                Task {
                    await environment.signOut()
                }
            } label: {
                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(DayframeColor.primary)
            }
            .accessibilityLabel("Log out")
            Button {
                model.showsDeleteConfirmation = true
            } label: {
                Label("Delete account", systemImage: "trash")
                    .foregroundStyle(Color("Danger"))
            }
            .accessibilityLabel("Delete account")
        } footer: {
            Text("Dayframe 0.1.0 — Frame your day. Schedule your story.")
        }
    }
}

#Preview("Profile") {
    NavigationStack {
        ProfileView()
    }
    .environment(AppEnvironment())
}

#Preview("Profile dark") {
    NavigationStack {
        ProfileView()
    }
    .environment(AppEnvironment())
    .environment(\.colorScheme, .dark)
}
