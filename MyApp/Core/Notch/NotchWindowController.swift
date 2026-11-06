import AppKit
import SwiftUI

final class NotchWindowController {

    private var panel: NSPanel?

    func show() {

        guard let screen = NSScreen.main else {
            return
        }

        let screenFrame = screen.frame
        let topSafeArea = screen.safeAreaInsets.top

        var notchWidth: CGFloat = 210

        if let leftArea = screen.auxiliaryTopLeftArea,
           let rightArea = screen.auxiliaryTopRightArea {

            notchWidth = rightArea.minX - leftArea.maxX

            print("⬅️ Left area:", leftArea)
            print("➡️ Right area:", rightArea)
        } else {
            print("⚠️ Auxiliary notch areas non disponibili")
        }

        print("🖥 Screen:", screenFrame)
        print("⬆️ Safe area top:", topSafeArea)
        print("🔳 Notch width:", notchWidth)

        let panelWidth: CGFloat = 520
        let panelHeight: CGFloat = 180

        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.maxY - panelHeight

        let panel = NSPanel(
            contentRect: NSRect(
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

        panel.contentView = NSHostingView(
            rootView: NotchView(
                notchWidth: notchWidth,
                notchHeight: topSafeArea
            )
        )

        panel.orderFrontRegardless()

        self.panel = panel
    }
}
