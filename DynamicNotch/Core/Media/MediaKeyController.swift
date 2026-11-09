import Foundation
import AppKit
import ApplicationServices

@MainActor
final class MediaKeyController {

    enum MediaKey: Int32 {
        case playPause = 16
        case next = 17
        case previous = 18
    }

    // MARK: - State

    private var didRequestAccessibilityThisLaunch =
        false

    // MARK: - Public

    func togglePlayback() {
        send(.playPause)
    }

    func nextTrack() {
        send(.next)
    }

    func previousTrack() {
        send(.previous)
    }

    // MARK: - Send

    private func send(
        _ key: MediaKey
    ) {

        guard checkAccessibilityPermission() else {

            print(
                "❌ Dynamic Notch non ha il permesso Accessibility"
            )

            return
        }

        print(
            "🎹 Invio media key:",
            key
        )

        post(
            key,
            down:
                true
        )

        post(
            key,
            down:
                false
        )
    }

    // MARK: - Post Event

    private func post(
        _ key: MediaKey,
        down:
            Bool
    ) {

        let flagValue:
            UInt =
                down
                ? 0xA00
                : 0xB00

        let data1 =
            Int(
                (key.rawValue << 16)
                |
                Int32(
                    flagValue
                )
            )

        let modifierFlags =
            NSEvent.ModifierFlags(
                rawValue:
                    flagValue
            )

        guard
            let event =
                NSEvent.otherEvent(
                    with:
                        .systemDefined,
                    location:
                        .zero,
                    modifierFlags:
                        modifierFlags,
                    timestamp:
                        ProcessInfo
                            .processInfo
                            .systemUptime,
                    windowNumber:
                        0,
                    context:
                        nil,
                    subtype:
                        8,
                    data1:
                        data1,
                    data2:
                        -1
                )
        else {

            print(
                "❌ Impossibile creare NSEvent"
            )

            return
        }

        guard
            let cgEvent =
                event.cgEvent
        else {

            print(
                "❌ NSEvent creato ma CGEvent è nil"
            )

            return
        }

        cgEvent.post(
            tap:
                .cghidEventTap
        )

        print(
            down
            ? "⬇️ MediaKey DOWN"
            : "⬆️ MediaKey UP"
        )
    }

    // MARK: - Accessibility

    private func checkAccessibilityPermission()
        -> Bool {

        if AXIsProcessTrusted() {

            return true
        }

        guard
            !didRequestAccessibilityThisLaunch
        else {

            return false
        }

        didRequestAccessibilityThisLaunch =
            true

        let options =
            [
                kAXTrustedCheckOptionPrompt
                    .takeUnretainedValue()
                    as String:
                        true
            ]
            as CFDictionary

        _ =
            AXIsProcessTrustedWithOptions(
                options
            )

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 0.8
        ) { [weak self] in

            guard
                let self
            else {
                return
            }

            guard
                !AXIsProcessTrusted()
            else {
                return
            }

            self.openAccessibilitySettings()
        }

        return false
    }

    // MARK: - Accessibility Settings

    private func openAccessibilitySettings() {

        let candidates =
            [
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
            ]

        for candidate in candidates {

            guard
                let url =
                    URL(
                        string:
                            candidate
                    )
            else {
                continue
            }

            if NSWorkspace.shared.open(
                url
            ) {

                print(
                    "⚙️ Aperte le impostazioni Accessibility"
                )

                return
            }
        }

        print(
            "❌ Impossibile aprire le impostazioni Accessibility"
        )
    }
}
