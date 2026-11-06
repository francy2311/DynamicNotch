import Foundation
import AppKit
import Combine

@MainActor
final class SystemNowPlayingProvider: ObservableObject {

    // MARK: - Published

    @Published
    var title: String = "Nessun brano"

    @Published
    var artist: String = ""

    @Published
    var album: String = ""

    @Published
    var artwork: NSImage?

    @Published
    var playerIcon: NSImage?

    @Published
    var isPlaying: Bool = false

    @Published
    var bundleIdentifier: String = ""

    @Published
    var duration: Double = 0

    @Published
    var elapsedTime: Double = 0

    @Published
    var timestamp: Date?

    // MARK: - Controller

    private let controller: any MediaController

    // MARK: - Default Init

    init() {

        let controller =
            DynamicNotchMediaController()

        self.controller =
            controller

        configureController(
            controller
        )
    }

    // MARK: - Custom Init

    init(
        controller: any MediaController
    ) {

        self.controller =
            controller

        configureController(
            controller
        )
    }

    // MARK: - Controller Setup

    private func configureController(
        _ controller: any MediaController
    ) {

        controller.onUpdate =
            { [weak self] snapshot in

                self?.apply(
                    snapshot
                )
            }

        controller.start()
    }

    // MARK: - Snapshot

    private func apply(
        _ snapshot:
            MediaPlaybackSnapshot
    ) {

        title =
            snapshot.title

        artist =
            snapshot.artist

        album =
            snapshot.album

        isPlaying =
            snapshot.isPlaying

        duration =
            snapshot.duration

        elapsedTime =
            snapshot.elapsedTime

        timestamp =
            snapshot.timestamp

        updateArtwork(
            snapshot.artworkData
        )

        updatePlayer(
            bundleIdentifier:
                snapshot.bundleIdentifier
        )
    }

    // MARK: - Artwork

    private func updateArtwork(
        _ data: Data?
    ) {

        guard
            let data,
            let image =
                NSImage(
                    data: data
                )
        else {

            artwork = nil
            return
        }

        artwork =
            image
    }

    // MARK: - Player Icon

    private func updatePlayer(
        bundleIdentifier:
            String
    ) {

        guard
            self.bundleIdentifier
                != bundleIdentifier
        else {
            return
        }

        self.bundleIdentifier =
            bundleIdentifier

        guard
            !bundleIdentifier.isEmpty
        else {

            playerIcon = nil
            return
        }

        guard
            let applicationURL =
                NSWorkspace
                    .shared
                    .urlForApplication(
                        withBundleIdentifier:
                            bundleIdentifier
                    )
        else {

            playerIcon = nil
            return
        }

        playerIcon =
            NSWorkspace
                .shared
                .icon(
                    forFile:
                        applicationURL.path
                )
    }

    // MARK: - Current Time

    func currentElapsedTime()
        -> Double {

        guard duration > 0 else {
            return 0
        }

        guard
            isPlaying,
            let timestamp
        else {

            return min(
                max(
                    elapsedTime,
                    0
                ),
                duration
            )
        }

        let delta =
            Date()
                .timeIntervalSince(
                    timestamp
                )

        return min(
            max(
                elapsedTime + delta,
                0
            ),
            duration
        )
    }

    // MARK: - Controls

    func togglePlayback() {

        controller
            .togglePlayback()
    }

    func nextTrack() {

        controller
            .nextTrack()
    }

    func previousTrack() {

        controller
            .previousTrack()
    }

    func seek(
        to seconds: Double
    ) {

        guard duration > 0 else {
            return
        }

        let position =
            min(
                max(
                    seconds,
                    0
                ),
                duration
            )

        controller.seek(
            to:
                position
        )

        elapsedTime =
            position

        timestamp =
            Date()
    }
}
