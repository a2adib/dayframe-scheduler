import SwiftUI

/// Connect Channels: platform list with Connect buttons, connected state with
/// a green check, and a Reconnect badge for expired tokens (AppFLOW 2.2,
/// UI_Spec §4.2). Mock OAuth connects after a short delay.
struct ConnectChannelsView: View {
    var onFinished: () -> Void
    var showsDoneButton: Bool = true

    @Environment(AppEnvironment.self) private var environment
    @State private var channels: [Channel] = []
    @State private var connectingPlatform: Platform?
    @State private var limitReached = false
    @State private var connectionError: String?

    private let allPlatforms: [Platform] = Platform.allCases

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(allPlatforms, id: \.self) { platform in
                        row(platform: platform)
                    }
                } header: {
                    Text("Channels")
                } footer: {
                    if limitReached {
                        Label("Free plan connects up to 3 channels. Upgrade to Pro for unlimited.", systemImage: "lock")
                            .foregroundStyle(Color("Warning"))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Connect Channels")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if showsDoneButton {
                    PrimaryButton(title: "Continue", action: onFinished)
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
    }

    private func load() async {
        channels = (try? await environment.channelRepository.loadChannels()) ?? []
    }

    private func row(platform: Platform) -> some View {
        let channel = channels.first { $0.platform == platform }
        let isConnecting = connectingPlatform == platform
        return HStack(spacing: DayframeSpacing.md) {
            ChannelAvatar(platform: platform, size: 44, showsBadge: false)
            VStack(alignment: .leading, spacing: DayframeSpacing.xs) {
                Text(platform.displayName)
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.textPrimary)
                if let channel {
                    Text(channel.handle)
                        .font(.system(size: 13))
                        .foregroundStyle(DayframeColor.textSecondary)
                }
            }
            Spacer()
            if isConnecting {
                ProgressView()
            } else if let channel {
                if channel.status == .expired {
                    Button("Reconnect") { Task { await reconnect(channel) } }
                        .buttonStyle(.plain)
                        .font(DayframeFont.chip)
                        .foregroundStyle(Color("Warning"))
                        .accessibilityLabel("Reconnect \(platform.displayName)")
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color("Success"))
                        .accessibilityLabel("\(platform.displayName) connected")
                }
            } else {
                Button("Connect") { Task { await connect(platform) } }
                    .buttonStyle(.plain)
                    .font(DayframeFont.chip)
                    .foregroundStyle(DayframeColor.primary)
                    .accessibilityLabel("Connect \(platform.displayName)")
            }
        }
        .padding(.vertical, DayframeSpacing.xs)
    }

    private func connect(_ platform: Platform) async {
        limitReached = channels.count >= 3
        guard !limitReached else { return }
        connectingPlatform = platform
        defer { connectingPlatform = nil }
        do {
            _ = try await environment.channelRepository.connect(platform)
            connectionError = nil
        } catch AppError.oauthCancelled {
            // User closed the provider window: no change, no error (AppFLOW 2.2).
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
            // User closed the provider window: no change, no error (AppFLOW 2.2).
        } catch {
            connectionError = error.localizedDescription
        }
        await load()
    }
}

#Preview("ConnectChannels") {
    ConnectChannelsView(onFinished: {})
}

#Preview("ConnectChannels dark") {
    ConnectChannelsView(onFinished: {})
        .environment(\.colorScheme, .dark)
}
