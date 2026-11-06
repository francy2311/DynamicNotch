import Foundation

@MainActor
final class DynamicNotchMediaController: MediaController {

    var onUpdate: ((MediaPlaybackSnapshot) -> Void)?

    private var pollingTask:
        Task<Void, Never>?

    private var artworkTask:
        Task<Void, Never>?

    private let mediaKeyController =
        MediaKeyController()

    // MARK: - State

    private var latestSnapshot:
        MediaPlaybackSnapshot =
            .empty

    private var latestTrackIdentity:
        String?

    // MARK: - Artwork Cache

    private var cachedArtworkData:
        Data?

    private var cachedArtworkIdentity:
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

                    let pollStartedAt =
                        Date()

                    if let json =
                        await Self.executeBridge(
                            frameworkPath:
                                binaryPath,
                            action:
                                "get"
                        ),
                       let snapshot =
                        self.parseMetadataSnapshot(
                            json
                        ) {

                        self.handleMetadataSnapshot(
                            snapshot,
                            frameworkPath:
                                binaryPath
                        )
                    }

                    /*
                     Metadata soltanto:
                     il payload adesso è molto piccolo.

                     Possiamo quindi fare polling
                     più rapido senza trasportare
                     artwork Base64 continuamente.
                     */

                    let elapsed =
                        Date()
                            .timeIntervalSince(
                                pollStartedAt
                            )

                    let targetInterval =
                        0.30

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

        pollingTask?
            .cancel()

        pollingTask =
            nil

        artworkTask?
            .cancel()

        artworkTask =
            nil
    }

    // MARK: - Metadata Handling

    private func handleMetadataSnapshot(
        _ incomingSnapshot: MediaPlaybackSnapshot,
        frameworkPath: String
    ) {

        let identity =
            Self.trackIdentity(
                incomingSnapshot
            )

        let trackChanged =
            identity
            != latestTrackIdentity

        var artworkData:
            Data?

        /*
         Se abbiamo già la copertina della
         stessa traccia, la riutilizziamo.
         */

        if cachedArtworkIdentity
            == identity {

            artworkData =
                cachedArtworkData

        } else {

            artworkData =
                nil
        }

        let snapshot =
            MediaPlaybackSnapshot(
                title:
                    incomingSnapshot.title,

                artist:
                    incomingSnapshot.artist,

                album:
                    incomingSnapshot.album,

                artworkData:
                    artworkData,

                bundleIdentifier:
                    incomingSnapshot.bundleIdentifier,

                isPlaying:
                    incomingSnapshot.isPlaying,

                duration:
                    incomingSnapshot.duration,

                elapsedTime:
                    incomingSnapshot.elapsedTime,

                timestamp:
                    incomingSnapshot.timestamp
            )

        latestSnapshot =
            snapshot

        latestTrackIdentity =
            identity

        /*
         Metadata vengono pubblicati SUBITO.

         La UI quindi non aspetta più
         che venga caricata la copertina.
         */

        onUpdate?(
            snapshot
        )

        // MARK: Artwork fetch

        guard trackChanged else {
            return
        }

        guard
            Self.hasValidMedia(
                snapshot
            )
        else {

            cachedArtworkData =
                nil

            cachedArtworkIdentity =
                nil

            artworkTask?
                .cancel()

            artworkTask =
                nil

            return
        }

        /*
         È cambiata traccia.

         Non vogliamo mai mostrare la
         copertina del brano precedente.
         */

        cachedArtworkData =
            nil

        cachedArtworkIdentity =
            nil

        artworkTask?
            .cancel()

        fetchArtwork(
            expectedIdentity:
                identity,
            frameworkPath:
                frameworkPath
        )
    }

    // MARK: - Artwork Fetch

    private func fetchArtwork(
        expectedIdentity: String,
        frameworkPath: String
    ) {

        artworkTask =
            Task { [weak self] in

                guard let self else {
                    return
                }

                let json =
                    await Self.executeBridge(
                        frameworkPath:
                            frameworkPath,
                        action:
                            "artwork"
                    )

                guard
                    !Task.isCancelled,
                    let json
                else {
                    return
                }

                guard
                    let artworkResult =
                        Self.parseArtwork(
                            json
                        )
                else {
                    return
                }

                /*
                 Verifica 1:
                 l'artwork restituito deve essere
                 della traccia che avevamo richiesto.
                 */

                guard
                    artworkResult.identity
                        == expectedIdentity
                else {

                    print(
                        "⚠️ Artwork scartato: traccia cambiata durante il caricamento"
                    )

                    return
                }

                /*
                 Verifica 2:
                 nel frattempo la UI deve essere
                 ancora sulla stessa traccia.
                 */

                guard
                    self.latestTrackIdentity
                        == expectedIdentity
                else {

                    return
                }

                self.cachedArtworkData =
                    artworkResult.data

                self.cachedArtworkIdentity =
                    expectedIdentity

                let current =
                    self.latestSnapshot

                let updated =
                    MediaPlaybackSnapshot(
                        title:
                            current.title,

                        artist:
                            current.artist,

                        album:
                            current.album,

                        artworkData:
                            artworkResult.data,

                        bundleIdentifier:
                            current.bundleIdentifier,

                        isPlaying:
                            current.isPlaying,

                        duration:
                            current.duration,

                        elapsedTime:
                            current.elapsedTime,

                        timestamp:
                            current.timestamp
                    )

                self.latestSnapshot =
                    updated

                self.onUpdate?(
                    updated
                )
            }
    }

    // MARK: - Parse Metadata

    private func parseMetadataSnapshot(
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

            return MediaPlaybackSnapshot(
                title:
                    title,

                artist:
                    artist,

                album:
                    album,

                artworkData:
                    nil,

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
                "❌ DynamicNotchMedia metadata JSON:",
                error
            )

            return nil
        }
    }

    // MARK: - Artwork Result

    private struct ArtworkResult {

        let identity:
            String

        let data:
            Data
    }

    nonisolated
    private static func parseArtwork(
        _ json: String
    ) -> ArtworkResult? {

        guard
            let jsonData =
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
                                jsonData
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
                ?? ""

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
                doubleValue(
                    payload[
                        "duration"
                    ]
                )

            guard
                let base64 =
                    payload[
                        "artworkData"
                    ]
                    as? String,
                let artworkData =
                    Data(
                        base64Encoded:
                            base64
                    )
            else {

                return nil
            }

            let identity =
                makeTrackIdentity(
                    title:
                        title,
                    artist:
                        artist,
                    album:
                        album,
                    duration:
                        duration
                )

            return ArtworkResult(
                identity:
                    identity,
                data:
                    artworkData
            )

        } catch {

            print(
                "❌ Artwork JSON:",
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

            } elsif ($action eq "artwork") {

                my $json =
                    DynamicNotchMedia::getArtwork();

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
                    "❌ Perl start:",
                    error
                )

                return nil
            }

            /*
             Metadata sono piccoli.

             Artwork può essere grande,
             ma viene richiesto soltanto
             al cambio traccia.

             Continuiamo comunque a drenare
             stdout prima di waitUntilExit().
             */

            let outputData =
                stdout
                    .fileHandleForReading
                    .readDataToEndOfFile()

            let errorData =
                stderr
                    .fileHandleForReading
                    .readDataToEndOfFile()

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
        }
        .value
    }

    // MARK: - Identity

    nonisolated
    private static func trackIdentity(
        _ snapshot: MediaPlaybackSnapshot
    ) -> String {

        makeTrackIdentity(
            title:
                snapshot.title,
            artist:
                snapshot.artist,
            album:
                snapshot.album,
            duration:
                snapshot.duration
        )
    }

    nonisolated
    private static func makeTrackIdentity(
        title: String,
        artist: String,
        album: String,
        duration: Double
    ) -> String {

        [
            title,
            artist,
            album,
            String(
                Int(duration)
            )
        ]
        .joined(
            separator:
                "|"
        )
    }

    nonisolated
    private static func hasValidMedia(
        _ snapshot: MediaPlaybackSnapshot
    ) -> Bool {

        let title =
            snapshot.title
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return
            !title.isEmpty
            &&
            title != "Nessun brano"
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
