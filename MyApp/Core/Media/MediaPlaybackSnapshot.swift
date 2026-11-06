import Foundation

struct MediaPlaybackSnapshot {

    let title: String
    let artist: String
    let album: String

    let artworkData: Data?

    let bundleIdentifier: String

    let isPlaying: Bool

    let duration: Double
    let elapsedTime: Double

    let timestamp: Date?

    static let empty = MediaPlaybackSnapshot(
        title: "Nessun brano",
        artist: "",
        album: "",
        artworkData: nil,
        bundleIdentifier: "",
        isPlaying: false,
        duration: 0,
        elapsedTime: 0,
        timestamp: nil
    )
}
