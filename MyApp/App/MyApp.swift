import SwiftUI
import AppKit

@main
struct MyApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var notchWindowController: NotchWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {

        // L'app non appare nel Dock
        NSApp.setActivationPolicy(.accessory)

        notchWindowController = NotchWindowController()
        notchWindowController?.show()
    }
}
