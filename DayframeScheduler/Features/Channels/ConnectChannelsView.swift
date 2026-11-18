import SwiftUI

/// Connect Channels: platform list with multi-channel support (Instagram, Facebook,
/// LinkedIn, X, Threads, TikTok), connection health badges (Connected, Needs Reauth,
/// Paused), per-channel "Pause Queue" toggle, and active account management.
struct ConnectChannelsView: View {
    var onFinished: () -> Void
    var showsDoneButton: Bool = true

    @Environment(AppEnvironment.self) private var environment
    @State private var channels: [Channel] = []
    @State private var connectingPlatform: Platform?
    @State private var limitReached = false
    @State private var connectionError: String?
    @State private var channelFilter: ChannelGroupFilter = .all

    enum ChannelGroupFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case paused = "Paused"
        case needsAttention = "Needs Reauth"

        var id: String { rawValue }
    }

    private let allPlatforms: [Platform] = [
        .instagram,
        .facebook,
        .linkedin,
        .x,
        .threads,
        .tiktok
    ]

    var filteredChannels: [Channel] {
        switch channelFilter {
        case .all:
            return channels
        case .active:
            return channels.filter { $0.connectionHealth == .connected }
        case .paused:
            return channels.filter { $0.connectionHealth == .paused }
        case .needsAttention:
            return channels.filter { $0.connectionHealth == .needsReauth }
        }
    }

    var body: some View {
        List {
            if !channels.isEmpty {
                Section {
                    Picker("Filter Channels", selection: $channelFilter) {
                        ForEach(ChannelGroupFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                    .listRowBackground(Color.clear)
                }
            }

            Section {
                ForEach(allPlatforms, id: \.self) { platform in
                    channelRow(platform: platform)
                }
            } header: {
                HStack {
                    Text("Social Profiles")
                    Spacer()
                    Text("\(channels.count) Connected")
                        .font(DayframeFont.caption)
                        .foregroundStyle(DayframeColor.textSecondary)
                }
            } footer: {
                VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                    if limitReached {
                        Label("Free plan connects up to 3 channels. Upgrade to Pro for unlimited.", systemImage: "lock")
                            .foregroundStyle(Color("Warning"))
                    }
                    Text("Pause Queue halts automated publishing for that network without deleting any scheduled posts.")
                        .font(.system(size: 12))
                        .foregroundStyle(DayframeColor.textSecondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Connect Channels")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if showsDoneButton {
                PrimaryButton(title: "Done", action: onFinished)
                    .padding(.horizontal, DayframeSpacing.xl)
                    .padding(.bottom, DayframeSpacing.lg)
            }
        }
        .task { await load() }
        .alert(
            "Couldn't connect",
            isPresented: Binding(
                get: { connectionError != nil },
                set: { if !$0 { connectionError = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(connectionError ?? "")
        }
    }

    private func load() async {
        channels = (try? await environment.channelRepository.loadChannels()) ?? []
    }

    private func channelRow(platform: Platform) -> some View {
        let channel = channels.first { $0.platform == platform }
        let isConnecting = connectingPlatform == platform

        return VStack(alignment: .leading, spacing: DayframeSpacing.sm) {
            HStack(spacing: DayframeSpacing.md) {
                ChannelAvatar(platform: platform, size: 44, showsBadge: false)

                VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                    HStack(spacing: DayframeSpacing.xs) {
                        Text(platform.displayName)
                            .font(DayframeFont.headline)
                            .foregroundStyle(DayframeColor.textPrimary)

                        if let channel {
                            ConnectionStatusBadge(health: channel.connectionHealth, compact: true)
                        }
                    }

                    if let channel {
                        Text(channel.handle)
                            .font(.system(size: 13))
                            .foregroundStyle(DayframeColor.textSecondary)
                    } else {
                        Text("Not connected")
                            .font(.system(size: 12))
                            .foregroundStyle(DayframeColor.textTertiary)
                    }
                }

                Spacer()

                if isConnecting {
                    ProgressView()
                        .padding(.horizontal, DayframeSpacing.sm)
                } else if let channel {
                    if channel.connectionHealth == .needsReauth {
                        Button {
                            Task { await reconnect(channel) }
                        } label: {
                            Text("Reconnect")
                                .font(DayframeFont.chip)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color("Warning"))
                                .padding(.horizontal, DayframeSpacing.md)
                                .padding(.vertical, DayframeSpacing.xs)
                                .background(Color("Warning").opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Reconnect \(platform.displayName)")
                    } else {
                        Menu {
                            Button(channel.isPaused ? "Resume Queue" : "Pause Queue", systemImage: channel.isPaused ? "play.circle" : "pause.circle") {
                                Task { await togglePause(channel) }
                            }
                            Button("Reconnect Account", systemImage: "arrow.clockwise") {
                                Task { await reconnect(channel) }
                            }
                            Divider()
                            Button("Disconnect", systemImage: "trash", role: .destructive) {
                                Task { await disconnect(channel) }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(DayframeColor.textSecondary)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    Button {
                        Task { await connect(platform) }
                    } label: {
                        Text("Connect")
                            .font(DayframeFont.chip)
                            .fontWeight(.semibold)
                            .foregroundStyle(DayframeColor.primary)
                            .padding(.horizontal, DayframeSpacing.md)
                            .padding(.vertical, DayframeSpacing.xs)
                            .background(DayframeColor.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Connect \(platform.displayName)")
                }
            }

            // Per-Channel "Pause Queue" toggle control when connected
            if let channel {
                Divider()
                    .padding(.top, 2)

                HStack {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pause Queue")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(DayframeColor.textPrimary)
                            Text(channel.isPaused ? "Publishing halted for this channel" : "Posts publish on schedule")
                                .font(.system(size: 11))
                                .foregroundStyle(channel.isPaused ? Color.orange : DayframeColor.textSecondary)
                        }
                    } icon: {
                        Image(systemName: channel.isPaused ? "pause.circle.fill" : "play.circle.fill")
                            .foregroundStyle(channel.isPaused ? Color.orange : Color("Success"))
                    }

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { channel.isPaused },
                        set: { _ in Task { await togglePause(channel) } }
                    ))
                    .labelsHidden()
                    .tint(Color.orange)
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, DayframeSpacing.xs)
    }

    private var isPro: Bool {
        environment.currentProfile?.plan == .pro
    }

    private func connect(_ platform: Platform) async {
        limitReached = !isPro && channels.count >= 3
        guard !limitReached else { return }
        connectingPlatform = platform
        defer { connectingPlatform = nil }
        do {
            _ = try await environment.channelRepository.connect(platform)
            connectionError = nil
        } catch AppError.oauthCancelled {
            // Cancelled
        } catch {
            connectionError = error.localizedDescription
        }
        await load()
    }

    private func reconnect(_ channel: Channel) async {
        connectingPlatform = channel.platform
        defer { connectingPlatform = nil }
        do {
            _ = try await environment.channelRepository.reconnect(channel)
            connectionError = nil
        } catch AppError.oauthCancelled {
            // Cancelled
        } catch {
            connectionError = error.localizedDescription
        }
        await load()
    }

    private func togglePause(_ channel: Channel) async {
        let newPaused = !channel.isPaused
        do {
            try await environment.channelRepository.togglePauseQueue(channelID: channel.id, isPaused: newPaused)
            if let idx = channels.firstIndex(where: { $0.id == channel.id }) {
                channels[idx].isPaused = newPaused
            }
        } catch {
            connectionError = "Could not update queue pause status: \(error.localizedDescription)"
        }
    }

    private func disconnect(_ channel: Channel) async {
        do {
            try await environment.channelRepository.disconnect(channel)
            await load()
        } catch {
            connectionError = "Could not disconnect: \(error.localizedDescription)"
        }
    }
}

#Preview("ConnectChannels") {
    NavigationStack {
        ConnectChannelsView(onFinished: {})
            .environment(AppEnvironment())
    }
}
