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

    private static var accessibilityPanel:
        NSPanel?

    // MARK: - Accessibility State

    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

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

        guard Self.isAccessibilityTrusted else {

            print(
                "❌ Dynamic Notch non ha il permesso Accessibility"
            )

            Self.showAccessibilityPanel()

            return
        }

        print(
            "🎹 Invio media key:",
            key
        )

        post(
            key,
            down: true
        )

        post(
            key,
            down: false
        )
    }

    // MARK: - Post Event

    private func post(
        _ key: MediaKey,
        down: Bool
    ) {

        let flagValue: UInt =
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

    // MARK: - Accessibility Panel

    private static func showAccessibilityPanel() {

        /*
         Se il pannello esiste già,
         lo riportiamo semplicemente davanti.
         */

        if let accessibilityPanel {

            NSApp.activate(
                ignoringOtherApps:
                    true
            )

            accessibilityPanel
                .makeKeyAndOrderFront(
                    nil
                )

            return
        }

        let panel =
            NSPanel(
                contentRect:
                    NSRect(
                        x:
                            0,
                        y:
                            0,
                        width:
                            440,
                        height:
                            220
                    ),
                styleMask: [
                    .titled,
                    .closable
                ],
                backing:
                    .buffered,
                defer:
                    false
            )

        panel.title =
            "Dynamic Notch"

        panel.isReleasedWhenClosed =
            false

        panel.level =
            .floating

        panel.center()

        // MARK: Content View

        let contentView =
            NSView(
                frame:
                    NSRect(
                        x:
                            0,
                        y:
                            0,
                        width:
                            440,
                        height:
                            220
                    )
            )

        panel.contentView =
            contentView

        // MARK: Icon

        let iconView =
            NSImageView()

        iconView.translatesAutoresizingMaskIntoConstraints =
            false

        iconView.image =
            NSImage(
                systemSymbolName:
                    "accessibility",
                accessibilityDescription:
                    "Accessibilità"
            )

        iconView.symbolConfiguration =
            NSImage.SymbolConfiguration(
                pointSize:
                    34,
                weight:
                    .medium
            )

        contentView.addSubview(
            iconView
        )

        // MARK: Title

        let titleLabel =
            NSTextField(
                labelWithString:
                    "Permesso Accessibilità richiesto"
            )

        titleLabel.translatesAutoresizingMaskIntoConstraints =
            false

        titleLabel.font =
            .systemFont(
                ofSize:
                    17,
                weight:
                    .semibold
            )

        contentView.addSubview(
            titleLabel
        )

        // MARK: Description

        let descriptionLabel =
            NSTextField(
                wrappingLabelWithString:
                    """
                    Dynamic Notch necessita del permesso Accessibilità per utilizzare i controlli multimediali.

                    Abilita Dynamic Notch in:
                    Impostazioni di Sistema → Privacy e Sicurezza → Accessibilità
                    """
            )

        descriptionLabel.translatesAutoresizingMaskIntoConstraints =
            false

        descriptionLabel.font =
            .systemFont(
                ofSize:
                    13
            )

        descriptionLabel.textColor =
            .secondaryLabelColor

        contentView.addSubview(
            descriptionLabel
        )

        // MARK: Cancel Button

        let cancelButton =
            NSButton(
                title:
                    "Annulla",
                target:
                    self,
                action:
                    #selector(
                        closeAccessibilityPanel
                    )
            )

        cancelButton.translatesAutoresizingMaskIntoConstraints =
            false

        cancelButton.bezelStyle =
            .rounded

        contentView.addSubview(
            cancelButton
        )

        // MARK: Open Settings Button

        let settingsButton =
            NSButton(
                title:
                    "Apri Impostazioni",
                target:
                    self,
                action:
                    #selector(
                        openAccessibilitySettingsFromPanel
                    )
            )

        settingsButton.translatesAutoresizingMaskIntoConstraints =
            false

        settingsButton.bezelStyle =
            .rounded

        settingsButton.keyEquivalent =
            "\r"

        contentView.addSubview(
            settingsButton
        )

        // MARK: Layout

        NSLayoutConstraint.activate(
            [

                iconView.leadingAnchor
                    .constraint(
                        equalTo:
                            contentView.leadingAnchor,
                        constant:
                            24
                    ),

                iconView.topAnchor
                    .constraint(
                        equalTo:
                            contentView.topAnchor,
                        constant:
                            26
                    ),

                iconView.widthAnchor
                    .constraint(
                        equalToConstant:
                            42
                    ),

                iconView.heightAnchor
                    .constraint(
                        equalToConstant:
                            42
                    ),

                titleLabel.leadingAnchor
                    .constraint(
                        equalTo:
                            iconView.trailingAnchor,
                        constant:
                            16
                    ),

                titleLabel.trailingAnchor
                    .constraint(
                        equalTo:
                            contentView.trailingAnchor,
                        constant:
                            -24
                    ),

                titleLabel.topAnchor
                    .constraint(
                        equalTo:
                            contentView.topAnchor,
                        constant:
                            26
                    ),

                descriptionLabel.leadingAnchor
                    .constraint(
                        equalTo:
                            titleLabel.leadingAnchor
                    ),

                descriptionLabel.trailingAnchor
                    .constraint(
                        equalTo:
                            contentView.trailingAnchor,
                        constant:
                            -24
                    ),

                descriptionLabel.topAnchor
                    .constraint(
                        equalTo:
                            titleLabel.bottomAnchor,
                        constant:
                            10
                    ),

                settingsButton.trailingAnchor
                    .constraint(
                        equalTo:
                            contentView.trailingAnchor,
                        constant:
                            -20
                    ),

                settingsButton.bottomAnchor
                    .constraint(
                        equalTo:
                            contentView.bottomAnchor,
                        constant:
                            -18
                    ),

                cancelButton.trailingAnchor
                    .constraint(
                        equalTo:
                            settingsButton.leadingAnchor,
                        constant:
                            -10
                    ),

                cancelButton.centerYAnchor
                    .constraint(
                        equalTo:
                            settingsButton.centerYAnchor
                    )
            ]
        )

        accessibilityPanel =
            panel

        NSApp.activate(
            ignoringOtherApps:
                true
        )

        panel.makeKeyAndOrderFront(
            nil
        )
    }

    // MARK: - Panel Actions

    @objc
    private static func closeAccessibilityPanel() {

        accessibilityPanel?
            .orderOut(
                nil
            )

        accessibilityPanel?
            .close()

        accessibilityPanel =
            nil
    }

    @objc
    private static func openAccessibilitySettingsFromPanel() {

        closeAccessibilityPanel()

        openAccessibilitySettings()
    }

    // MARK: - Manual Accessibility Request

    @discardableResult
    static func requestAccessibilityPermission()
        -> Bool {

        if AXIsProcessTrusted() {
            return true
        }

        let options =
            [
                kAXTrustedCheckOptionPrompt
                    .takeUnretainedValue()
                    as String:
                        true
            ]
            as CFDictionary

        return AXIsProcessTrustedWithOptions(
            options
        )
    }

    // MARK: - Accessibility Settings

    static func openAccessibilitySettings() {

        let candidates = [

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
