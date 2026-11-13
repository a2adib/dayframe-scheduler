import Foundation

enum PlanTier: String, Codable {
    case free
    case pro
}

enum ScheduleMode: String, Codable {
    case queue
    case custom
    case now
}

enum ChannelStatus: String, Codable {
    case connected
    case expired
    case revoked
}

enum MediaKind: String, Codable {
    case image
    case video
}
