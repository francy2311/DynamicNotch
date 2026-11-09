import AppKit
import CoreGraphics

enum NotchScreenResolver {

    static func preferredScreen() -> NSScreen? {

        switch AppSettings.shared.displayMode {

        case .automatic:

            if let builtInScreen = builtInScreen() {
                return builtInScreen
            }

            if let mainScreen = NSScreen.main {
                return mainScreen
            }

            return NSScreen.screens.first

        case .mainDisplay:

            return NSScreen.main
                ?? NSScreen.screens.first

        case .allDisplays:

            /*
             Per ora NotchWindowController gestisce
             una sola finestra.

             Quindi temporaneamente usiamo la stessa
             logica di automatic.

             Quando implementeremo davvero
             "Tutti i display", creeremo un panel
             per ogni NSScreen.
             */

            if let builtInScreen = builtInScreen() {
                return builtInScreen
            }

            return NSScreen.main
                ?? NSScreen.screens.first
        }
    }

    static func builtInScreen() -> NSScreen? {

        NSScreen.screens.first { screen in

            guard let displayID = displayID(
                for: screen
            ) else {
                return false
            }

            return CGDisplayIsBuiltin(
                displayID
            ) != 0
        }
    }

    static func displayID(
        for screen: NSScreen
    ) -> CGDirectDisplayID? {

        guard
            let screenNumber =
                screen.deviceDescription[
                    NSDeviceDescriptionKey(
                        "NSScreenNumber"
                    )
                ] as? NSNumber
        else {
            return nil
        }

        return CGDirectDisplayID(
            screenNumber.uint32Value
        )
    }

    static func isBuiltIn(
        _ screen: NSScreen
    ) -> Bool {

        guard
            let displayID =
                displayID(
                    for: screen
                )
        else {
            return false
        }

        return CGDisplayIsBuiltin(
            displayID
        ) != 0
    }
}
