import Foundation

@MainActor
final class DynamicNotchMediaController: MediaController {

    var onUpdate: ((MediaPlaybackSnapshot) -> Void)?

    private var pollingTask:
        Task<Void, Never>?

    private let mediaKeyController =
        MediaKeyController()

    private var cachedArtworkData: Data?

    private var cachedTrackIdentity:
        String?

    // MARK: - Start

    func start() {

        guard pollingTask == nil else {
            return
        }

        guard
            let binaryPath =
                dynamicNotchMediaBinaryPath()
        else {

            print(
                "❌ DynamicNotchMedia.framework non trovato"
            )

            return
        }

        print(
            "✅ DynamicNotchMedia:",
            binaryPath
        )

        pollingTask =
            Task { [weak self] in

                guard let self else {
                    return
                }

                while !Task.isCancelled {

                    if let json =
                        await Self.executeBridge(
                            frameworkPath:
                                binaryPath,
                            action:
                                "get"
                        ) {

                        if let snapshot =
                            self.parseCustomSnapshot(
                                json
                            ) {

                            self.onUpdate?(
                                snapshot
                            )
                        }
                    }

                    do {

                        try await Task.sleep(
                            for:
                                .seconds(1)
                        )

                    } catch {

                        break
                    }
                }
            }
    }

    // MARK: - Stop

    func stop() {

        pollingTask?.cancel()

        pollingTask =
            nil
    }

    // MARK: - Parse

    private func parseCustomSnapshot(
        _ json: String
    ) -> MediaPlaybackSnapshot? {

        guard
            let data =
                json.data(
                    using:
                        .utf8
                )
        else {
            return nil
        }

        do {

            guard
                let payload =
                    try JSONSerialization
                        .jsonObject(
                            with:
                                data
                        )
                    as? [String: Any]
            else {

                return nil
            }

            let title =
                payload[
                    "title"
                ]
                as? String
                ?? "Nessun brano"

            let artist =
                payload[
                    "artist"
                ]
                as? String
                ?? ""

            let album =
                payload[
                    "album"
                ]
                as? String
                ?? ""

            let bundleIdentifier =
                payload[
                    "bundleIdentifier"
                ]
                as? String
                ?? ""

            let duration =
                Self.doubleValue(
                    payload[
                        "duration"
                    ]
                )

            let elapsedTime =
                Self.doubleValue(
                    payload[
                        "elapsedTime"
                    ]
                )

            let isPlaying =
                Self.boolValue(
                    payload[
                        "playing"
                    ]
                )

            // MARK: Timestamp

            let timestamp:
                Date?

            if let value =
                payload[
                    "timestamp"
                ]
                as? NSNumber {

                timestamp =
                    Date(
                        timeIntervalSince1970:
                            value.doubleValue
                    )

            } else {

                timestamp =
                    Date()
            }

            // MARK: Artwork

            let trackIdentity =
                [
                    bundleIdentifier,
                    title,
                    artist,
                    album
                ]
                .joined(
                    separator:
                        "|"
                )

            var artworkData:
                Data?

            if let base64 =
                payload[
                    "artworkData"
                ]
                as? String,
               let decoded =
                Data(
                    base64Encoded:
                        base64
                ) {

                artworkData =
                    decoded

                cachedArtworkData =
                    decoded

                cachedTrackIdentity =
                    trackIdentity

            } else if
                cachedTrackIdentity
                    == trackIdentity {

                artworkData =
                    cachedArtworkData

            } else {

                cachedArtworkData =
                    nil

                cachedTrackIdentity =
                    trackIdentity

                artworkData =
                    nil
            }

            return MediaPlaybackSnapshot(
                title:
                    title,

                artist:
                    artist,

                album:
                    album,

                artworkData:
                    artworkData,

                bundleIdentifier:
                    bundleIdentifier,

                isPlaying:
                    isPlaying,

                duration:
                    duration,

                elapsedTime:
                    elapsedTime,

                timestamp:
                    timestamp
            )

        } catch {

            print(
                "❌ DynamicNotchMedia JSON:",
                error
            )

            return nil
        }
    }

    // MARK: - Universal Controls

    func togglePlayback() {

        mediaKeyController
            .togglePlayback()
    }

    func nextTrack() {

        mediaKeyController
            .nextTrack()
    }

    func previousTrack() {

        mediaKeyController
            .previousTrack()
    }

    // MARK: - Seek

    func seek(
        to seconds: Double
    ) {

        print(
            "⏱ DynamicNotch seek:",
            seconds
        )

        executeCommand(
            "seek",
            value:
                seconds
        )
    }

    // MARK: - Command

    private func executeCommand(
        _ action: String,
        value: Double? = nil
    ) {

        guard
            let binaryPath =
                dynamicNotchMediaBinaryPath()
        else {

            print(
                "❌ Framework non trovato:",
                action
            )

            return
        }

        Task {

            let result =
                await Self.executeBridge(
                    frameworkPath:
                        binaryPath,
                    action:
                        action,
                    value:
                        value
                )

            if let result {

                print(
                    "✅ \(action):",
                    result
                )

            } else {

                print(
                    "❌ DynamicNotchMedia command fallito:",
                    action
                )
            }
        }
    }

    // MARK: - Framework Path

    private func dynamicNotchMediaBinaryPath()
        -> String? {

        guard
            let resources =
                Bundle.main
                    .resourceURL
        else {

            return nil
        }

        let binaryURL =
            resources
                .appendingPathComponent(
                    "DynamicNotchMedia"
                )
                .appendingPathComponent(
                    "DynamicNotchMedia.framework"
                )
                .appendingPathComponent(
                    "DynamicNotchMedia"
                )

        guard
            FileManager.default
                .fileExists(
                    atPath:
                        binaryURL.path
                )
        else {

            print(
                "❌ Framework cercato in:",
                binaryURL.path
            )

            return nil
        }

        return binaryURL.path
    }

    // MARK: - Perl Bridge

    nonisolated
    private static func executeBridge(
        frameworkPath: String,
        action: String,
        value: Double? = nil
    ) async -> String? {

        await Task.detached {

            let perlScript = #"""
            use strict;
            use warnings;
            use DynaLoader;

            my $library = shift @ARGV;
            my $action  = shift @ARGV;
            my $value   = shift @ARGV;

            my $libref =
                DynaLoader::dl_load_file(
                    $library,
                    0
                );

            if (!$libref) {
                die DynaLoader::dl_error();
            }

            my $symbol =
                DynaLoader::dl_find_symbol(
                    $libref,
                    "boot_DynamicNotchMedia"
                );

            if (!$symbol) {
                die DynaLoader::dl_error();
            }

            my $bootstrap =
                DynaLoader::dl_install_xsub(
                    "DynamicNotchMedia::bootstrap",
                    $symbol,
                    $library
                );

            $bootstrap->();

            if ($action eq "get") {

                my $json =
                    DynamicNotchMedia::get();

                if (defined $json) {
                    print $json;
                }

            } elsif ($action eq "seek") {

                die "Missing seek value"
                    unless defined $value;

                print DynamicNotchMedia::seek(
                    $value
                );

            } else {

                die "Unknown action: $action";
            }
            """#

            let process =
                Process()

            let stdout =
                Pipe()

            let stderr =
                Pipe()

            process.executableURL =
                URL(
                    fileURLWithPath:
                        "/usr/bin/perl"
                )

            var arguments = [
                "-e",
                perlScript,
                frameworkPath,
                action
            ]

            if let value {

                arguments.append(
                    String(
                        value
                    )
                )
            }

            process.arguments =
                arguments

            process.standardOutput =
                stdout

            process.standardError =
                stderr

            do {

                try process.run()

            } catch {

                print(
                    "❌ Perl:",
                    error
                )

                return nil
            }

            /*
             IMPORTANTISSIMO

             Leggiamo stdout e stderr mentre il processo
             è ancora in esecuzione.

             Prima facevamo:

                 process.waitUntilExit()
                 readDataToEndOfFile()

             Con artwork Base64 molto grande la pipe
             poteva riempirsi e bloccare Perl.

             Perl aspettava Swift.
             Swift aspettava che Perl terminasse.

             Deadlock.
             */

            async let outputDataTask: Data = {
                stdout
                    .fileHandleForReading
                    .readDataToEndOfFile()
            }()

            async let errorDataTask: Data = {
                stderr
                    .fileHandleForReading
                    .readDataToEndOfFile()
            }()

            let outputData =
                await outputDataTask

            let errorData =
                await errorDataTask

            process
                .waitUntilExit()

            if process.terminationStatus != 0 {

                if let message =
                    String(
                        data:
                            errorData,
                        encoding:
                            .utf8
                    ),
                   !message.isEmpty {

                    print(
                        "❌ Perl bridge:",
                        message
                    )
                }

                return nil
            }

            guard
                let output =
                    String(
                        data:
                            outputData,
                        encoding:
                            .utf8
                    )
            else {

                return nil
            }

            let trimmed =
                output
                    .trimmingCharacters(
                        in:
                            .whitespacesAndNewlines
                    )

            return trimmed.isEmpty
                ? nil
                : trimmed
        }.value
    }

    // MARK: - Helpers

    nonisolated
    private static func doubleValue(
        _ value: Any?
    ) -> Double {

        if let value =
            value as? Double {

            return value
        }

        if let value =
            value as? Int {

            return Double(
                value
            )
        }

        if let value =
            value as? NSNumber {

            return value
                .doubleValue
        }

        return 0
    }

    nonisolated
    private static func boolValue(
        _ value: Any?
    ) -> Bool {

        if let value =
            value as? Bool {

            return value
        }

        if let value =
            value as? NSNumber {

            return value
                .boolValue
        }

        return false
    }
}
