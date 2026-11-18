import Foundation

/// Platform targets (Schema.md section 1: `platform` enum).
enum Platform: String, Codable, CaseIterable, Identifiable {
    case instagram
    case x
    case linkedin
    case facebook
    case threads
    case tiktok
    case youtube

    var id: String { rawValue }
}
