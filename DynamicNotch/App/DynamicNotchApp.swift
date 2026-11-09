import SwiftUI
import AppKit

@main
struct DynamicNotchApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {

        /*
         Non utilizziamo MenuBarExtra e non utilizziamo
         la Settings scene di SwiftUI.

         Menu bar e finestra Impostazioni vengono
         gestite direttamente dall'AppDelegate.
         */

        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate:
    NSObject,
    NSApplicationDelegate,
    NSWindowDelegate {

    // MARK: - Notch

    private var notchWindowController:
        NotchWindowController?

    private var notchIsVisible =
        true

    // MARK: - Menu Bar

    private var statusItem:
        NSStatusItem?

    private var visibilityMenuItem:
        NSMenuItem?

    // MARK: - Settings

    private var settingsWindow:
        NSWindow?

    // MARK: - Launch

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {

        /*
         LSUIElement = YES rende Dynamic Notch
         una utility senza icona Dock.
         */

        setupMenuBar()

        let controller =
            NotchWindowController()

        notchWindowController =
            controller

        controller.show()
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {

        let item =
            NSStatusBar.system.statusItem(
                withLength:
                    NSStatusItem.squareLength
            )

        statusItem =
            item

        if let button =
            item.button {

            if let image =
                NSImage(
                    named:
                        "MenuBarIcon"
                ) {

                image.isTemplate =
                    true

                image.size =
                    NSSize(
                        width:
                            18,
                        height:
                            12
                    )

                button.image =
                    image

            } else {

                button.image =
                    NSImage(
                        systemSymbolName:
                            "rectangle.topthird.inset.filled",
                        accessibilityDescription:
                            "Dynamic Notch"
                    )
            }

            button.toolTip =
                "Dynamic Notch"
        }

        let menu =
            NSMenu()

        let settingsItem =
            NSMenuItem(
                title:
                    "Impostazioni…",
                action:
                    #selector(
                        openSettings
                    ),
                keyEquivalent:
                    ","
            )

        settingsItem.target =
            self

        menu.addItem(
            settingsItem
        )

        menu.addItem(
            .separator()
        )

        let visibilityItem =
            NSMenuItem(
                title:
                    "Nascondi Dynamic Notch",
                action:
                    #selector(
                        toggleNotchVisibility
                    ),
                keyEquivalent:
                    ""
            )

        visibilityItem.target =
            self

        visibilityMenuItem =
            visibilityItem

        menu.addItem(
            visibilityItem
        )

        menu.addItem(
            .separator()
        )

        let quitItem =
            NSMenuItem(
                title:
                    "Esci da Dynamic Notch",
                action:
                    #selector(
                        quitApplication
                    ),
                keyEquivalent:
                    "q"
            )

        quitItem.target =
            self

        menu.addItem(
            quitItem
        )

        item.menu =
            menu
    }

    // MARK: - Settings

    @objc
    private func openSettings() {

        /*
         Se la finestra esiste già,
         la riportiamo semplicemente davanti.
         */

        if let settingsWindow {

            NSApp.setActivationPolicy(
                .regular
            )

            NSApp.activate(
                ignoringOtherApps:
                    true
            )

            settingsWindow.makeKeyAndOrderFront(
                nil
            )

            return
        }

        /*
         Creiamo manualmente la finestra.

         Non utilizziamo più openSettings(),
         SettingsLink o showSettingsWindow:.
         */

        let hostingController =
            NSHostingController(
                rootView:
                    SettingsView()
            )

        let window =
            NSWindow(
                contentRect:
                    NSRect(
                        x:
                            0,
                        y:
                            0,
                        width:
                            620,
                        height:
                            520
                    ),
                styleMask: [
                    .titled,
                    .closable,
                    .miniaturizable
                ],
                backing:
                    .buffered,
                defer:
                    false
            )

        window.title =
            "Dynamic Notch – Impostazioni"

        window.contentViewController =
            hostingController

        window.isReleasedWhenClosed =
            false

        window.delegate =
            self

        window.center()

        settingsWindow =
            window

        /*
         L'icona Dock compare soltanto
         quando apriamo manualmente
         le Impostazioni.
         */

        NSApp.setActivationPolicy(
            .regular
        )

        NSApp.activate(
            ignoringOtherApps:
                true
        )

        window.makeKeyAndOrderFront(
            nil
        )
    }

    // MARK: - Settings Close

    func windowWillClose(
        _ notification: Notification
    ) {

        guard
            let closingWindow =
                notification.object
                    as? NSWindow,
            closingWindow === settingsWindow
        else {
            return
        }

        settingsWindow =
            nil

        /*
         Aspettiamo che AppKit termini
         la chiusura prima di tornare
         alla modalità utility.
         */

        DispatchQueue.main.async {

            NSApp.setActivationPolicy(
                .accessory
            )
        }
    }

    // MARK: - Notch Visibility

    @objc
    private func toggleNotchVisibility() {

        notchIsVisible.toggle()

        guard
            let controller =
                notchWindowController
        else {
            return
        }

        if notchIsVisible {

            controller.show()

            visibilityMenuItem?.title =
                "Nascondi Dynamic Notch"

        } else {

            controller.hide()

            visibilityMenuItem?.title =
                "Mostra Dynamic Notch"
        }
    }

    // MARK: - Quit

    @objc
    private func quitApplication() {

        NSApp.terminate(
            nil
        )
    }

    // MARK: - Application Behaviour

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {

        /*
         Chiudere Settings non deve
         terminare Dynamic Notch.
         */

        false
    }

    func applicationShouldSaveSecureApplicationState(
        _ app: NSApplication
    ) -> Bool {

        false
    }

    func applicationShouldRestoreSecureApplicationState(
        _ app: NSApplication
    ) -> Bool {

        false
    }
}
