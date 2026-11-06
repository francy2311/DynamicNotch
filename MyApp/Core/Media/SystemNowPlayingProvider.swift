import Foundation
import AppKit
import Combine

@MainActor
final class SystemNowPlayingProvider: ObservableObject {

    @Published var title: String = "Nessun brano"
    @Published var artist: String = ""
    @Published var album: String = ""

    @Published var artwork: NSImage?
    @Published var playerIcon: NSImage?

    @Published var isPlaying: Bool = false
    @Published var bundleIdentifier: String = ""

    @Published var duration: Double = 0
    @Published var elapsedTime: Double = 0
    @Published var timestamp: Date?

    private var process: Process?
    private var pipe: Pipe?
    private var streamTask: Task<Void, Never>?

    init() {
        start()
    }

    deinit {
        streamTask?.cancel()
        process?.terminate()
    }

    // MARK: - Start

    private func start() {

        guard process == nil else {
            return
        }

        guard let executable = mediaControlPath() else {
            print("❌ media-control non trovato")
            return
        }

        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(
            fileURLWithPath: executable
        )

        process.arguments = [
            "stream",
            "--no-diff"
        ]

        process.standardOutput = pipe
        process.standardError = FileHandle.standardError

        do {

            try process.run()

            self.process = process
            self.pipe = pipe

            startReading(
                from: pipe.fileHandleForReading
            )

        } catch {

            print(
                "❌ media-control NON avviato:",
                error
            )
        }
    }

    // MARK: - Stream

    private func startReading(
        from handle: FileHandle
    ) {

        streamTask = Task { [weak self] in

            do {

                for try await line in handle.bytes.lines {

                    guard !Task.isCancelled else {
                        break
                    }

                    self?.parse(line)
                }

            } catch {

                if !Task.isCancelled {
                    print(
                        "❌ Errore stream:",
                        error
                    )
                }
            }
        }
    }

    // MARK: - Parse

    private func parse(
        _ line: String
    ) {

        guard let data = line.data(
            using: .utf8
        ) else {
            return
        }

        do {

            guard
                let json =
                    try JSONSerialization
                        .jsonObject(with: data)
                    as? [String: Any],

                let payload =
                    json["payload"]
                    as? [String: Any]

            else {
                return
            }

            if payload.isEmpty {

                title = "Nessun brano"
                artist = ""
                album = ""

                artwork = nil
                playerIcon = nil

                isPlaying = false
                bundleIdentifier = ""

                duration = 0
                elapsedTime = 0
                timestamp = nil

                return
            }

            title =
                payload["title"] as? String
                ?? "Nessun brano"

            artist =
                payload["artist"] as? String
                ?? ""

            album =
                payload["album"] as? String
                ?? ""

            isPlaying =
                payload["playing"] as? Bool
                ?? false

            bundleIdentifier =
                payload["bundleIdentifier"]
                as? String
                ?? ""

            updatePlayerIcon()

            if let value =
                payload["duration"] as? Double {

                duration = value

            } else if let value =
                payload["duration"] as? Int {

                duration = Double(value)

            } else {

                duration = 0
            }

            if let value =
                payload["elapsedTime"] as? Double {

                elapsedTime = value

            } else if let value =
                payload["elapsedTime"] as? Int {

                elapsedTime = Double(value)

            } else {

                elapsedTime = 0
            }

            if let value =
                payload["timestamp"] as? String {

                timestamp =
                    ISO8601DateFormatter()
                        .date(from: value)

            } else {

                timestamp = nil
            }

            if let base64 =
                payload["artworkData"] as? String {

                updateArtwork(base64)

            } else {

                artwork = nil
            }

        } catch {

            print(
                "❌ JSON non valido:",
                error
            )
        }
    }

    // MARK: - Current Time

    func currentElapsedTime() -> Double {

        guard duration > 0 else {
            return 0
        }

        guard isPlaying,
              let timestamp else {

            return min(
                max(elapsedTime, 0),
                duration
            )
        }

        let delta =
            Date().timeIntervalSince(timestamp)

        return min(
            max(
                elapsedTime + delta,
                0
            ),
            duration
        )
    }

    // MARK: - Seek

    func seek(to seconds: Double) {

        guard duration > 0 else {
            return
        }

        let position = min(
            max(seconds, 0),
            duration
        )

        execute(
            arguments: [
                "seek",
                String(position)
            ]
        )

        elapsedTime = position
        timestamp = Date()
    }

    // MARK: - Artwork

    private func updateArtwork(
        _ base64: String
    ) {

        guard
            let data =
                Data(
                    base64Encoded: base64
                ),

            let image =
                NSImage(data: data)

        else {

            artwork = nil
            return
        }

        artwork = image
    }

    // MARK: - Player Icon

    private func updatePlayerIcon() {

        guard !bundleIdentifier.isEmpty else {
            playerIcon = nil
            return
        }

        guard let appURL =
            NSWorkspace.shared
                .urlForApplication(
                    withBundleIdentifier:
                        bundleIdentifier
                )
        else {

            playerIcon = nil
            return
        }

        playerIcon =
            NSWorkspace.shared.icon(
                forFile: appURL.path
            )
    }

    // MARK: - Controls

    func togglePlayback() {
        execute(
            arguments: [
                "toggle-play-pause"
            ]
        )
    }

    func nextTrack() {
        execute(
            arguments: [
                "next-track"
            ]
        )
    }

    func previousTrack() {
        execute(
            arguments: [
                "previous-track"
            ]
        )
    }

    // MARK: - Execute

    private func execute(
        arguments: [String]
    ) {

        guard let executable =
            mediaControlPath()
        else {
            return
        }

        let process = Process()

        process.executableURL =
            URL(
                fileURLWithPath: executable
            )

        process.arguments = arguments

        do {
            try process.run()

        } catch {

            print(
                "❌ media-control:",
                error
            )
        }
    }

    // MARK: - Path

    private func mediaControlPath()
        -> String? {

        let paths = [
            "/opt/homebrew/bin/media-control",
            "/usr/local/bin/media-control"
        ]

        return paths.first {
            FileManager.default
                .isExecutableFile(
                    atPath: $0
                )
        }
    }
}
