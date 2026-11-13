import Foundation

struct Profile: Identifiable, Equatable {
    var id: UUID
    var displayName: String
    var avatarURL: URL?
    var timezone: String
    var theme: Theme
    var plan: PlanTier

    enum Theme: String, Codable {
        case system
        case light
        case dark
    }
}
