import SwiftUI

@MainActor
struct FeatureRailView: View {

    // MARK: - Mode

    let selectedMode:
        NotchView.ContentMode

    // MARK: - Timer

    let isTimerRunning:
        Bool

    // MARK: - Selection

    let onSelect:
        (NotchView.ContentMode) -> Void

    // MARK: - Body

    var body: some View {

        HStack(
            spacing:
                8
        ) {

            featureTab(
                mode:
                    .media,
                icon:
                    "music.note"
            )

            featureTab(
                mode:
                    .volume,
                icon:
                    "speaker.wave.2.fill"
            )

            featureTab(
                mode:
                    .brightness,
                icon:
                    "sun.max.fill"
            )

            featureTab(
                mode:
                    .timer,
                icon:
                    isTimerRunning
                    ? "timer"
                    : "stopwatch"
            )

            featureTab(
                mode:
                    .more,
                icon:
                    "ellipsis"
            )
        }
    }

    // MARK: - Feature Tab

    private func featureTab(
        mode:
            NotchView.ContentMode,
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
                    4
            ) {

                ZStack {

                    RoundedRectangle(
                        cornerRadius:
                            8,
                        style:
                            .continuous
                    )
                    .fill(
                        Color.white
                            .opacity(
                                selected
                                ? 0.14
                                : 0.05
                            )
                    )

                    Image(
                        systemName:
                            icon
                    )
                    .font(
                        .system(
                            size:
                                11,
                            weight:
                                .semibold
                        )
                    )
                    .foregroundStyle(
                        selected
                        ? .white
                        : .secondary
                    )
                }
                .frame(
                    width:
                        38,
                    height:
                        26
                )

                Capsule()
                    .fill(
                        selected
                        ? Color.white
                        : Color.clear
                    )
                    .frame(
                        width:
                            14,
                        height:
                            2
                    )
            }
        }
        .buttonStyle(
            .plain
        )
    }
}
