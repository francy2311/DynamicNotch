import AppKit
import SwiftUI
import Combine
import CoreGraphics

@MainActor
final class NotchWindowController {

    private struct NotchGeometry: Equatable {
        let width: CGFloat
        let height: CGFloat
    }

    private var panels:
        [CGDirectDisplayID: NSPanel] = [:]

    private var panelGeometries:
        [CGDirectDisplayID: NotchGeometry] = [:]

    private var screenObserver:
        NSObjectProtocol?

    private var cancellables =
        Set<AnyCancellable>()

    private var isVisible = true

    init() {
        startObservingScreens()
        startObservingSettings()
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default
                .removeObserver(
                    screenObserver
                )
        }

        cancellables.removeAll()
    }

    // MARK: - Show / Hide

    func show() {
        isVisible = true
        refreshPanels()
    }

    func hide() {
        isVisible = false

        for panel in panels.values {
            panel.orderOut(nil)
        }
    }

    // MARK: - Screen Observer

    private func startObservingScreens() {
        guard screenObserver == nil else {
            return
        }

        screenObserver =
            NotificationCenter.default
                .addObserver(
                    forName:
                        NSApplication
                            .didChangeScreenParametersNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?
                            .screenConfigurationDidChange()
                    }
                }
    }

    // MARK: - Settings Observer

    private func startObservingSettings() {
        AppSettings.shared
            .$displayMode
            .removeDuplicates()
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in
                MainActor.assumeIsolated {
                    print(
                        "⚙️ Display mode cambiato:",
                        mode.rawValue
                    )

                    self?.refreshPanels()
                }
            }
            .store(
                in: &cancellables
            )
    }

    // MARK: - Screen Change

    private func screenConfigurationDidChange() {
        print(
            "🖥 Configurazione monitor aggiornata"
        )

        refreshPanels()
    }

    // MARK: - Refresh

    private func refreshPanels() {
        switch AppSettings.shared.displayMode {
        case .automatic:
            guard
                let screen =
                    NotchScreenResolver
                        .preferredScreen()
            else {
                removeAllPanels()
                return
            }

            showOnly(on: screen)

        case .mainDisplay:
            guard
                let screen =
                    NSScreen.main
                    ?? NSScreen.screens.first
            else {
                removeAllPanels()
                return
            }

            showOnly(on: screen)

        case .allDisplays:
            showOnAllDisplays()
        }
    }

    // MARK: - Single Display

    private func showOnly(
        on screen: NSScreen
    ) {
        guard
            let displayID =
                NotchScreenResolver
                    .displayID(
                        for: screen
                    )
        else {
            return
        }

        let otherDisplayIDs =
            panels.keys.filter {
                $0 != displayID
            }

        for id in otherDisplayIDs {
            removePanel(for: id)
        }

        if let panel = panels[displayID] {
            updatePanel(
                panel,
                on: screen,
                displayID: displayID
            )

            return
        }

        createPanel(
            on: screen,
            displayID: displayID
        )
    }

    // MARK: - All Displays

    private func showOnAllDisplays() {
        let screens =
            NSScreen.screens

        let activeDisplayIDs =
            Set(
                screens.compactMap {
                    NotchScreenResolver
                        .displayID(
                            for: $0
                        )
                }
            )

        let obsoleteDisplayIDs =
            panels.keys.filter {
                !activeDisplayIDs.contains($0)
            }

        for id in obsoleteDisplayIDs {
            removePanel(for: id)
        }

        for screen in screens {
            guard
                let displayID =
                    NotchScreenResolver
                        .displayID(
                            for: screen
                        )
            else {
                continue
            }

            if let panel = panels[displayID] {
                updatePanel(
                    panel,
                    on: screen,
                    displayID: displayID
                )
            } else {
                createPanel(
                    on: screen,
                    displayID: displayID
                )
            }
        }
    }

    // MARK: - Create Panel

    private func createPanel(
        on screen: NSScreen,
        displayID: CGDirectDisplayID
    ) {
        let screenFrame =
            screen.frame

        let notchHeight =
            resolvedNotchHeight(
                for: screen
            )

        let notchWidth =
            resolvedNotchWidth(
                for: screen
            )

        let panelWidth: CGFloat = 520
        let panelHeight: CGFloat = 180

        let x =
            screenFrame.midX
            - panelWidth / 2

        let y =
            screenFrame.maxY
            - panelHeight

        let panel =
            NSPanel(
                contentRect:
                    NSRect(
                        x: x,
                        y: y,
                        width: panelWidth,
                        height: panelHeight
                    ),
                styleMask: [
                    .borderless,
                    .nonactivatingPanel
                ],
                backing: .buffered,
                defer: false
            )

        panel.level = .statusBar

        panel.isOpaque = false

        panel.backgroundColor = .clear

        panel.hasShadow = false

        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary
        ]

        panel.contentView =
            makeHostingView(
                notchWidth: notchWidth,
                notchHeight: notchHeight
            )

        panels[displayID] = panel

        panelGeometries[displayID] =
            NotchGeometry(
                width: notchWidth,
                height: notchHeight
            )

        if isVisible {
            panel.orderFrontRegardless()
        }

        logScreen(
            screen,
            action: "creata"
        )
    }

    // MARK: - Update Panel

    private func updatePanel(
        _ panel: NSPanel,
        on screen: NSScreen,
        displayID: CGDirectDisplayID
    ) {
        let screenFrame =
            screen.frame

        let panelWidth =
            panel.frame.width

        let panelHeight =
            panel.frame.height

        let x =
            screenFrame.midX
            - panelWidth / 2

        let y =
            screenFrame.maxY
            - panelHeight

        panel.setFrameOrigin(
            NSPoint(
                x: x,
                y: y
            )
        )

        let notchWidth =
            resolvedNotchWidth(
                for: screen
            )

        let notchHeight =
            resolvedNotchHeight(
                for: screen
            )

        let newGeometry =
            NotchGeometry(
                width: notchWidth,
                height: notchHeight
            )

        /*
         PRIMA:

         ogni refresh faceva:

         panel.contentView =
             NSHostingView(
                 rootView: NotchView(...)
             )

         quindi distruggeva la vecchia UI
         e ne creava una nuova.

         ADESSO:

         ricreiamo NotchView soltanto se
         è realmente cambiata la geometria
         fisica della notch.
         */

        if panelGeometries[displayID] != newGeometry {
            print(
                "📐 Geometria notch cambiata:",
                displayID
            )

            panel.contentView =
                makeHostingView(
                    notchWidth: notchWidth,
                    notchHeight: notchHeight
                )

            panelGeometries[displayID] =
                newGeometry
        }

        if isVisible {
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }

        logScreen(
            screen,
            action: "aggiornata"
        )
    }

    // MARK: - Hosting View

    private func makeHostingView(
        notchWidth: CGFloat,
        notchHeight: CGFloat
    ) -> NSView {
        NSHostingView(
            rootView:
                NotchView(
                    notchWidth: notchWidth,
                    notchHeight: notchHeight
                )
        )
    }

    // MARK: - Remove Panel

    private func removePanel(
        for displayID: CGDirectDisplayID
    ) {
        guard
            let panel =
                panels.removeValue(
                    forKey: displayID
                )
        else {
            return
        }

        panelGeometries
            .removeValue(
                forKey: displayID
            )

        panel.orderOut(nil)

        /*
         Togliendo contentView liberiamo
         NSHostingView → NotchView →
         SystemNowPlayingProvider.

         Il deinit del provider chiamerà
         quindi controller.stop().
         */

        panel.contentView = nil

        panel.close()

        print(
            "🗑 Panel rimosso:",
            displayID
        )
    }

    private func removeAllPanels() {
        let ids =
            Array(
                panels.keys
            )

        for id in ids {
            removePanel(for: id)
        }
    }

    // MARK: - Geometry

    private func resolvedNotchWidth(
        for screen: NSScreen
    ) -> CGFloat {
        if
            let leftArea =
                screen.auxiliaryTopLeftArea,
            let rightArea =
                screen.auxiliaryTopRightArea
        {
            let width =
                rightArea.minX
                - leftArea.maxX

            print(
                "⬅️ Left area:",
                leftArea
            )

            print(
                "➡️ Right area:",
                rightArea
            )

            return width
        }

        return 210
    }

    private func resolvedNotchHeight(
        for screen: NSScreen
    ) -> CGFloat {
        let safeArea =
            screen.safeAreaInsets.top

        if safeArea > 0 {
            return safeArea
        }

        return 38
    }

    // MARK: - Logging

    private func logScreen(
        _ screen: NSScreen,
        action: String
    ) {
        if NotchScreenResolver
            .isBuiltIn(screen) {

            print(
                "💻 Dynamic Notch \(action) sul display integrato"
            )
        } else {
            print(
                "🖥 Dynamic Notch \(action) sul display esterno"
            )
        }
    }
}
