import Foundation

@MainActor
final class DynamicNotchMediaController: MediaController {

    var onUpdate: ((MediaPlaybackSnapshot) -> Void)?

    private var pollingTask:
        Task<Void, Never>?

    private let mediaKeyController =
        MediaKeyController()

    // MARK: - Artwork Cache

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

                    let pollStart =
                        Date()

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

                    /*
                     Polling più rapido.

                     Prima era 1 secondo e il cambio
                     traccia poteva essere percepito
                     con parecchio ritardo.

                     350 ms è un buon compromesso
                     finché artwork e metadata
                     viaggiano ancora insieme.
                     */

                    let elapsed =
                        Date()
                            .timeIntervalSince(
                                pollStart
                            )

                    let targetInterval =
                        0.35

                    let remaining =
                        targetInterval
                        - elapsed

                    if remaining > 0 {

                        do {

                            try await Task.sleep(
                                for:
                                    .seconds(
                                        remaining
                                    )
                            )

                        } catch {

                            break
                        }
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

    // MARK: - Parse Snapshot

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

            // MARK: Metadata

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

            // MARK: Track Identity

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

            // MARK: Artwork

            var artworkData:
                Data?

            if let base64 =
                payload[
                    "artworkData"
                ]
                as? String,
               !base64.isEmpty,
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

        await Task.detached(
            priority:
                .userInitiated
        ) {

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

            // MARK: Start

            do {

                try process.run()

            } catch {

                print(
                    "❌ Perl start:",
                    error
                )

                return nil
            }

            /*
             Dreniamo stdout mentre Perl
             è ancora in esecuzione.

             Questo evita il deadlock
             causato dagli artwork Base64
             più grandi.
             */

            let outputData =
                stdout
                    .fileHandleForReading
                    .readDataToEndOfFile()

            let errorData =
                stderr
                    .fileHandleForReading
                    .readDataToEndOfFile()

            process.waitUntilExit()

            // MARK: Errors

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

            // MARK: Output

            guard
                let output =
                    String(
                        data:
                            outputData,
                        encoding:
                            .utf8
                    )
            else {

                print(
                    "❌ Output Perl non UTF-8"
                )

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
        }
        .value
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

        if let value =
            value as? String,
           let number =
            Double(
                value
            ) {

            return number
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

        if let value =
            value as? String {

            switch value.lowercased() {

            case "true",
                 "1",
                 "yes":

                return true

            default:

                return false
            }
        }

        return false
    }
}
