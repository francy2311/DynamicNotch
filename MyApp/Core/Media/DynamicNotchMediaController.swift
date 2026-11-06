import Foundation

@MainActor
final class DynamicNotchMediaController: MediaController {

    var onUpdate: ((MediaPlaybackSnapshot) -> Void)?

    private var pollingTask:
        Task<Void, Never>?

    // Ancora temporaneo SOLO per:
    // - artwork
    // - bundleIdentifier
    private let legacyController =
        MediaControlCLIController()

    private let mediaKeyController =
        MediaKeyController()

    private var legacySnapshot:
        MediaPlaybackSnapshot = .empty

    private var customEngineWorking =
        false

    // MARK: - Start

    func start() {

        guard pollingTask == nil else {
            return
        }

        startLegacyController()

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

                            self.customEngineWorking =
                                true

                            self.onUpdate?(
                                snapshot
                            )
                        }

                    } else if
                        !self.customEngineWorking {

                        self.onUpdate?(
                            self.legacySnapshot
                        )
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

        legacyController
            .stop()
    }

    // MARK: - Legacy metadata

    private func startLegacyController() {

        legacyController.onUpdate =
            { [weak self] snapshot in

                guard let self else {
                    return
                }

                self.legacySnapshot =
                    snapshot

                if !self.customEngineWorking {

                    self.onUpdate?(
                        snapshot
                    )
                }
            }

        legacyController.start()
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

            let timestamp:
                Date

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

            return MediaPlaybackSnapshot(
                title:
                    title,

                artist:
                    artist,

                album:
                    album,

                artworkData:
                    legacySnapshot
                        .artworkData,

                bundleIdentifier:
                    legacySnapshot
                        .bundleIdentifier,

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

    // MARK: - Controls

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
            seconds,
            "player:",
            legacySnapshot
                .bundleIdentifier
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

    // MARK: - Framework

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

    // MARK: - Perl bridge

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

                process
                    .waitUntilExit()

            } catch {

                print(
                    "❌ Perl:",
                    error
                )

                return nil
            }

            let outputData =
                stdout
                    .fileHandleForReading
                    .readDataToEndOfFile()

            let errorData =
                stderr
                    .fileHandleForReading
                    .readDataToEndOfFile()

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
