import Foundation
import AppKit
import Combine

final class NowPlayingService: ObservableObject {

    @Published var title: String = "Nessun brano"
    @Published var artist: String = ""
    @Published var artwork: NSImage?
    @Published var isPlaying: Bool = false

    func update(
        title: String,
        artist: String,
        artwork: NSImage? = nil,
        isPlaying: Bool
    ) {
        self.title = title
        self.artist = artist
        self.artwork = artwork
        self.isPlaying = isPlaying
    }
}
