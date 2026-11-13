import SwiftUI

/// First-run onboarding: three swipeable pages with Skip / Next
/// (AppFLOW 2.1). Illustrations are SF Symbols on soft gradient cards.
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var pageIndex = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(id: 0, title: "Plan", message: "Write once and tailor it for every channel in one calm composer.", systemImage: "square.and.pencil"),
        OnboardingPage(id: 1, title: "Schedule", message: "Fill your queue with weekly time slots, or pick the exact moment to post.", systemImage: "calendar.badge.clock"),
        OnboardingPage(id: 2, title: "Analyze", message: "See reach, engagement, and your top posts at a glance.", systemImage: "chart.line.uptrend.xyaxis"),
    ]

    var body: some View {
        VStack(spacing: DayframeSpacing.xl) {
            TabView(selection: $pageIndex) {
                ForEach(pages) { page in
                    pageView(page)
                        .padding(.horizontal, DayframeSpacing.xl)
                        .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: pageIndex)

            HStack {
                Button("Skip") { onFinish() }
                    .font(DayframeFont.headline)
                    .foregroundStyle(DayframeColor.textSecondary)
                    .accessibilityLabel("Skip onboarding")
                Spacer()
                Button(pageIndex == pages.count - 1 ? "Get started" : "Next") {
                    if pageIndex < pages.count - 1 {
                        pageIndex += 1
                    } else {
                        onFinish()
                    }
                }
                .buttonStyle(.plain)
                .font(DayframeFont.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, DayframeSpacing.xl)
                .padding(.vertical, DayframeSpacing.md)
                .background(DayframeColor.brandGradient)
                .clipShape(Capsule())
                .accessibilityLabel(pageIndex == pages.count - 1 ? "Get started" : "Next page")
            }
            .padding(.horizontal, DayframeSpacing.xl)
            .padding(.bottom, DayframeSpacing.xl)
        }
        .background(DayframeColor.background)
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: DayframeSpacing.xl) {
            Image(systemName: page.systemImage)
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 160, height: 160)
                .background(DayframeColor.brandGradient)
                .clipShape(RoundedRectangle(cornerRadius: DayframeRadius.sheet, style: .continuous))
                .accessibilityHidden(true)

            VStack(spacing: DayframeSpacing.md) {
                Text(page.title)
                    .font(DayframeFont.largeTitle(28))
                    .foregroundStyle(DayframeColor.textPrimary)
                Text(page.message)
                    .font(DayframeFont.body)
                    .foregroundStyle(DayframeColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

#Preview("Onboarding") {
    OnboardingView(onFinish: {})
}
