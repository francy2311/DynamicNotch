import Foundation

@MainActor
final class MediaControlCLIController: MediaController {

    var onUpdate: ((MediaPlaybackSnapshot) -> Void)?

    private var process: Process?
    private var pipe: Pipe?
    private var streamTask: Task<Void, Never>?

    // MARK: - Start

    func start() {

        guard process == nil else {
            return
        }

        guard let executable = mediaControlPath() else {
            print("❌ media-control non trovato")
            onUpdate?(.empty)
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
                "❌ Impossibile avviare media-control:",
                error
            )

            onUpdate?(.empty)
        }
    }

    // MARK: - Stop

    func stop() {

        streamTask?.cancel()
        streamTask = nil

        if process?.isRunning == true {
            process?.terminate()
        }

        process = nil
        pipe = nil
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

                    guard let self else {
                        break
                    }

                    self.parse(line)
                }

            } catch {

                if !Task.isCancelled {
                    print(
                        "❌ Errore lettura media-control:",
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

        guard
            let data = line.data(
                using: .utf8
            )
        else {
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

                onUpdate?(.empty)
                return
            }

            let snapshot = MediaPlaybackSnapshot(
                title:
                    payload["title"]
                    as? String
                    ?? "Nessun brano",

                artist:
                    payload["artist"]
                    as? String
                    ?? "",

                album:
                    payload["album"]
                    as? String
                    ?? "",

                artworkData:
                    artworkData(
                        from:
                            payload["artworkData"]
                    ),

                bundleIdentifier:
                    payload["bundleIdentifier"]
                    as? String
                    ?? "",

                isPlaying:
                    boolValue(
                        payload["playing"]
                    ),

                duration:
                    doubleValue(
                        payload["duration"]
                    ),

                elapsedTime:
                    doubleValue(
                        payload["elapsedTime"]
                    ),

                timestamp:
                    dateValue(
                        payload["timestamp"]
                    )
            )

            onUpdate?(
                snapshot
            )

        } catch {

            print(
                "❌ JSON media-control non valido:",
                error
            )
        }
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

    func seek(
        to seconds: Double
    ) {

        execute(
            arguments: [
                "seek",
                String(seconds)
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

            print(
                "❌ media-control non trovato"
            )

            return
        }

        let process = Process()

        process.executableURL =
            URL(
                fileURLWithPath:
                    executable
            )

        process.arguments =
            arguments

        do {

            try process.run()

        } catch {

            print(
                "❌ Errore comando media-control:",
                error
            )
        }
    }

    // MARK: - Helpers

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

    private func doubleValue(
        _ value: Any?
    ) -> Double {

        if let value = value as? Double {
            return value
        }

        if let value = value as? Int {
            return Double(value)
        }

        if let value = value as? NSNumber {
            return value.doubleValue
        }

        return 0
    }

    private func boolValue(
        _ value: Any?
    ) -> Bool {

        if let value = value as? Bool {
            return value
        }

        if let value = value as? NSNumber {
            return value.boolValue
        }

        return false
    }

    private func dateValue(
        _ value: Any?
    ) -> Date? {

        guard
            let string = value as? String
        else {
            return nil
        }

        return ISO8601DateFormatter()
            .date(from: string)
    }

    private func artworkData(
        from value: Any?
    ) -> Data? {

        guard
            let base64 = value as? String
        else {
            return nil
        }

        return Data(
            base64Encoded: base64
        )
    }
}
