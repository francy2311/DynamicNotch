import Foundation
import Combine
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    enum DisplayMode: String, CaseIterable, Identifiable {
        case automatic
        case mainDisplay
        case allDisplays

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .automatic:
                return "Automatico"

            case .mainDisplay:
                return "Display principale"

            case .allDisplays:
                return "Tutti i display"
            }
        }
    }

    // MARK: - General

    @Published var launchAtLogin: Bool {
        didSet {
            updateLaunchAtLogin()
        }
    }

    // MARK: - Display

    @Published var displayMode: DisplayMode {
        didSet {
            UserDefaults.standard.set(
                displayMode.rawValue,
                forKey: Keys.displayMode
            )
        }
    }

    // MARK: - Media

    @Published var revealOnTrackChange: Bool {
        didSet {
            UserDefaults.standard.set(
                revealOnTrackChange,
                forKey: Keys.revealOnTrackChange
            )
        }
    }

    @Published var revealOnPlaybackStart: Bool {
        didSet {
            UserDefaults.standard.set(
                revealOnPlaybackStart,
                forKey: Keys.revealOnPlaybackStart
            )
        }
    }

    @Published var mediaRevealDuration: Double {
        didSet {

            let safeValue =
                min(
                    max(
                        mediaRevealDuration,
                        1.0
                    ),
                    5.0
                )

            if safeValue != mediaRevealDuration {
                mediaRevealDuration = safeValue
                return
            }

            UserDefaults.standard.set(
                safeValue,
                forKey: Keys.mediaRevealDuration
            )
        }
    }

    // MARK: - Init

    private init() {

        self.launchAtLogin =
            SMAppService.mainApp.status == .enabled

        // Display

        if let rawValue =
            UserDefaults.standard.string(
                forKey: Keys.displayMode
            ),
           let mode =
            DisplayMode(
                rawValue: rawValue
            ) {

            self.displayMode =
                mode

        } else {

            self.displayMode =
                .automatic
        }

        // Reveal on track change

        if UserDefaults.standard.object(
            forKey: Keys.revealOnTrackChange
        ) == nil {

            self.revealOnTrackChange =
                true

        } else {

            self.revealOnTrackChange =
                UserDefaults.standard.bool(
                    forKey: Keys.revealOnTrackChange
                )
        }

        // Reveal on playback start

        if UserDefaults.standard.object(
            forKey: Keys.revealOnPlaybackStart
        ) == nil {

            self.revealOnPlaybackStart =
                true

        } else {

            self.revealOnPlaybackStart =
                UserDefaults.standard.bool(
                    forKey: Keys.revealOnPlaybackStart
                )
        }

        // Reveal duration

        if UserDefaults.standard.object(
            forKey: Keys.mediaRevealDuration
        ) == nil {

            self.mediaRevealDuration =
                2.5

        } else {

            let storedValue =
                UserDefaults.standard.double(
                    forKey: Keys.mediaRevealDuration
                )

            self.mediaRevealDuration =
                min(
                    max(
                        storedValue,
                        1.0
                    ),
                    5.0
                )
        }
    }

    // MARK: - Keys

    private enum Keys {

        static let displayMode =
            "displayMode"

        static let revealOnTrackChange =
            "revealOnTrackChange"

        static let revealOnPlaybackStart =
            "revealOnPlaybackStart"

        static let mediaRevealDuration =
            "mediaRevealDuration"
    }

    // MARK: - Launch At Login

    private func updateLaunchAtLogin() {

        do {

            if launchAtLogin {

                try SMAppService.mainApp.register()

            } else {

                try SMAppService.mainApp.unregister()
            }

        } catch {

            print(
                "❌ Launch at Login error:",
                error
            )
        }
    }
}
