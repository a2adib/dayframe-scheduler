import SwiftUI

/// Typography tokens (UI_Spec.md section 2). System font; rounded design for
/// display and wordmark styles.
enum DayframeFont {
    static func largeTitle(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    static let sectionHeader = Font.system(size: 24, weight: .bold)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let chip = Font.system(size: 15, weight: .semibold)
    static let caption = Font.system(size: 13, weight: .semibold)
}
