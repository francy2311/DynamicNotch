import SwiftUI

@MainActor
struct OverflowNavigationView: View {

    // MARK: - Mode

    let selectedMode:
        NotchView.OverflowMode

    // MARK: - Battery

    let batterySystemImage:
        String

    // MARK: - Selection

    let onSelect:
        (NotchView.OverflowMode) -> Void

    // MARK: - Body

    var body: some View {

        HStack(
            spacing:
                5
        ) {

            overflowButton(
                mode:
                    .clipboard,
                title:
                    "Clipboard",
                icon:
                    "clipboard"
            )

            overflowButton(
                mode:
                    .shelf,
                title:
                    "Shelf",
                icon:
                    "tray.full.fill"
            )

            overflowButton(
                mode:
                    .agenda,
                title:
                    "Agenda",
                icon:
                    "calendar"
            )

            overflowButton(
                mode:
                    .battery,
                title:
                    "Batteria",
                icon:
                    batterySystemImage
            )
        }
        .padding(
            .horizontal,
            18
        )
    }

    // MARK: - Button

    private func overflowButton(
        mode:
            NotchView.OverflowMode,
        title:
            String,
        icon:
            String
    ) -> some View {

        let selected =
            selectedMode == mode

        return Button {

            onSelect(
                mode
            )

        } label: {

            VStack(
                spacing:
                    3
            ) {

                Image(
                    systemName:
                        icon
                )
                .font(
                    .system(
                        size:
                            10,
                        weight:
                            .semibold
                    )
                )

                Text(
                    title
                )
                .font(
                    .system(
                        size:
                            8,
                        weight:
                            .semibold
                    )
                )
                .lineLimit(
                    1
                )
            }
            .foregroundStyle(
                selected
                ? .white
                : .secondary
            )
            .frame(
                maxWidth:
                    .infinity
            )
            .frame(
                height:
                    32
            )
            .background(
                Color.white
                    .opacity(
                        selected
                        ? 0.13
                        : 0.04
                    )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        8,
                    style:
                        .continuous
                )
            )
        }
        .buttonStyle(
            .plain
        )
    }
}
