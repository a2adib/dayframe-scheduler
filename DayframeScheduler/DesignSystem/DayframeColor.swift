import SwiftUI

/// Design-system color tokens. Light values are pixel-measured from the
/// Figma Queue frame (node 4-3); dark values are defaults (no dark screens
/// exist in Figma yet). See UI_Spec.md section 2.
enum DayframeColor {
    static let primary = Color("Primary")
    static let accent = Color("Accent")
    static let success = Color("Success")
    static let warning = Color("Warning")
    static let danger = Color("Danger")
    static let background = Color("Background")
    static let surface = Color("Surface")
    static let border = Color("Border")
    static let textPrimary = Color("TextPrimary")
    static let textSecondary = Color("TextSecondary")
    static let textTertiary = Color("TextTertiary")
    static let brandBlue = Color("BrandBlue")
    static let brandPurple = Color("BrandPurple")
    static let logoAmber = Color("LogoAmber")
    static let statusScheduledBackground = Color("StatusScheduledBackground")
    static let statusScheduledText = Color("StatusScheduledText")

    static let brandGradient = LinearGradient(
        colors: [brandBlue, brandPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
