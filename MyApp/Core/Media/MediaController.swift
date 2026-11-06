import Foundation

@MainActor
protocol MediaController: AnyObject {

    var onUpdate: ((MediaPlaybackSnapshot) -> Void)? {
        get set
    }

    func start()

    func stop()

    func togglePlayback()

    func nextTrack()

    func previousTrack()

    func seek(to seconds: Double)
}
