import SwiftUI

/// Loading skeleton: shimmering surface block. Screens compose these into
/// card/row layouts while data loads (UI_Spec §6).
struct SkeletonView: View {
    var width: CGFloat?
    var height: CGFloat = 16
    var cornerRadius: CGFloat = DayframeRadius.input

    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DayframeColor.surface)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.6), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.7)
                    .offset(x: phase * geo.size.width * 1.7)
                }
            )
            .clipped()
            .frame(width: width, height: height)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview("Skeleton") {
    VStack(alignment: .leading, spacing: DayframeSpacing.md) {
        SkeletonView(width: 120, height: 24)
        SkeletonView(height: 56)
        SkeletonView(height: 56)
        HStack {
            SkeletonView(width: 40, height: 40, cornerRadius: 20)
            SkeletonView(height: 16)
        }
    }
    .padding()
    .background(DayframeColor.background)
}

#Preview("Skeleton dark") {
    SkeletonView(height: 56)
        .padding()
        .background(DayframeColor.background)
        .environment(\.colorScheme, .dark)
}
