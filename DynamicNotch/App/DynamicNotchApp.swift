import SwiftUI
import AppKit

@main
struct DynamicNotchApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    @State
    private var notchIsVisible = true

    var body: some Scene {

        // MARK: - Settings

        Settings {

            SettingsView()
        }

        // MARK: - Menu Bar

        MenuBarExtra {

            SettingsLink {

                Label(
                    "Impostazioni…",
                    systemImage: "gear"
                )
            }

            Divider()

            Button {

                notchIsVisible.toggle()

                appDelegate.setNotchVisible(
                    notchIsVisible
                )

            } label: {

                Label(
                    notchIsVisible
                    ? "Nascondi Dynamic Notch"
                    : "Mostra Dynamic Notch",

                    systemImage:
                        notchIsVisible
                        ? "eye.slash"
                        : "eye"
                )
            }

            Divider()

            Button {

                NSApp.terminate(nil)

            } label: {

                Label(
                    "Esci da Dynamic Notch",
                    systemImage: "power"
                )
            }
            .keyboardShortcut("q")

        } label: {

            Image("MenuBarIcon")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(
                    width: 18,
                    height: 12
                )
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate:
    NSObject,
    NSApplicationDelegate {

    private var notchWindowController:
        NotchWindowController?

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {

        let notchController =
            NotchWindowController()

        notchWindowController =
            notchController

        notchController.show()
    }

    // MARK: - Visibility

    func setNotchVisible(
        _ visible: Bool
    ) {

        guard let controller =
            notchWindowController
        else {
            return
        }

        if visible {

            controller.show()

        } else {

            controller.hide()
        }
    }
}
