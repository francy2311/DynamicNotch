import Foundation
import AppKit

@MainActor
final class SeekRouter {

    func seek(
        bundleIdentifier: String,
        to seconds: Double,
        fallback: @escaping () -> Void
    ) {

        switch bundleIdentifier {

        case "com.spotify.client":
            seekSpotify(to: seconds)

        case "com.apple.Music":
            seekAppleMusic(to: seconds)

        default:
            fallback()
        }
    }

    // MARK: - Spotify

    private func seekSpotify(
        to seconds: Double
    ) {

        let script = """
        tell application "Spotify"
            set player position to \(seconds)
        end tell
        """

        executeAppleScript(
            script,
            label: "Spotify"
        )
    }

    // MARK: - Apple Music

    private func seekAppleMusic(
        to seconds: Double
    ) {

        let script = """
        tell application "Music"
            set player position to \(seconds)
        end tell
        """

        executeAppleScript(
            script,
            label: "Music"
        )
    }

    // MARK: - AppleScript

    private func executeAppleScript(
        _ source: String,
        label: String
    ) {

        guard let script =
            NSAppleScript(
                source: source
            )
        else {
            print(
                "❌ Impossibile creare AppleScript per \(label)"
            )
            return
        }

        var error:
            NSDictionary?

        script.executeAndReturnError(
            &error
        )

        if let error {

            print(
                "❌ Seek \(label):",
                error
            )

        } else {

            print(
                "✅ Seek \(label)"
            )
        }
    }
}
