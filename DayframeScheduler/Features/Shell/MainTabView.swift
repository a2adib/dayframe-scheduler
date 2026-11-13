import SwiftUI

/// Main navigation shell matching the Figma Queue mock (node 4-3): full-width
/// white tab bar with a 1px top hairline, Queue / Calendar / Analytics /
/// Profile items, and the Create action as a raised gradient button in the
/// center slot that opens the Composer full-screen sheet (AppFLOW §1).
struct MainTabView: View {
    private enum Tab: Int {
        case queue, calendar, analytics, profile
    }

    @State private var selection: Tab = .queue
    @State private var showsComposer = false

    var body: some View {
        Group {
            switch selection {
            case .queue: QueueView()
            case .calendar: CalendarView()
            case .analytics: AnalyticsView()
            case .profile: ProfileView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $showsComposer) {
            ComposerView(onSaved: { showsComposer = false })
        }
    }

    private var tabBar: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                tabButton(.queue, title: "Queue", icon: "list.bullet")
                tabButton(.calendar, title: "Calendar", icon: "calendar")
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 1)
                    .accessibilityHidden(true)
                tabButton(.analytics, title: "Analytics", icon: "chart.bar")
                tabButton(.profile, title: "Profile", icon: "person.circle")
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, DayframeSpacing.lg)
            .padding(.bottom, DayframeSpacing.xs)

            FloatingCreateButton(action: { showsComposer = true })
                .offset(y: 20)
        }
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            Rectangle()
                .fill(DayframeColor.background)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(DayframeColor.border)
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(
        _ tab: Tab,
        title: String,
        icon: String
    ) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: DayframeSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .symbolVariant(isSelected ? .fill : .none)
                Text(title)
                    .font(DayframeFont.caption)
            }
            .foregroundStyle(isSelected ? DayframeColor.primary : DayframeColor.textTertiary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("Shell") {
    MainTabView()
}

#Preview("Shell dark") {
    MainTabView()
        .environment(\.colorScheme, .dark)
}
