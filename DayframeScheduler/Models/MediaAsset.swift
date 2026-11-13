import Foundation

struct MediaAsset: Identifiable, Equatable {
    var id: UUID
    var storagePath: String
    var kind: MediaKind
    var width: Int?
    var height: Int?
    var durationMS: Int?
    var position: Int
}
