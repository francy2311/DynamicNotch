import SwiftUI

@MainActor
struct MediaView: View {

    // MARK: - Provider

    @ObservedObject
    var nowPlaying:
        SystemNowPlayingProvider

    // MARK: - Interaction

    let onSeekInteractionChanged:
        (Bool) -> Void

    // MARK: - Seek State

    @State
    private var isSeeking =
        false

    @State
    private var seekValue:
        Double = 0

    // MARK: - Body

    var body: some View {

        VStack(
            spacing:
                9
        ) {

            HStack(
                spacing:
                    12
            ) {

                MediaArtworkView(
                    artwork:
                        nowPlaying.artwork
                )

                mediaInformation

                Spacer(
                    minLength:
                        8
                )

                MediaControlsView(
                    nowPlaying:
                        nowPlaying
                )
            }

            seekSection
        }
        .buttonStyle(
            .plain
        )
        .foregroundStyle(
            .white
        )
        .padding(
            .horizontal,
            20
        )
        .padding(
            .bottom,
            10
        )
    }

    // MARK: - Information

    private var mediaInformation:
        some View {

        VStack(
            alignment:
                .leading,
            spacing:
                4
        ) {

            HStack(
                spacing:
                    6
            ) {

                if let playerIcon =
                    nowPlaying.playerIcon {

                    Image(
                        nsImage:
                            playerIcon
                    )
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width:
                            13,
                        height:
                            13
                    )
                }

                Text(
                    nowPlaying.title
                )
                .font(
                    .system(
                        size:
                            13,
                        weight:
                            .semibold
                    )
                )
                .lineLimit(
                    1
                )
            }

            Text(
                nowPlaying.artist
            )
            .font(
                .system(
                    size:
                        11
                )
            )
            .foregroundStyle(
                .secondary
            )
            .lineLimit(
                1
            )
        }
        .frame(
            maxWidth:
                160,
            alignment:
                .leading
        )
    }

    // MARK: - Seek

    @ViewBuilder
    private var seekSection:
        some View {

        if nowPlaying.duration > 0 {

            TimelineView(
                .periodic(
                    from:
                        .now,
                    by:
                        0.25
                )
            ) { _ in

                let current =
                    nowPlaying
                        .currentElapsedTime()

                Slider(
                    value:
                        Binding(
                            get: {

                                isSeeking
                                ? seekValue
                                : current
                            },
                            set: {

                                seekValue =
                                    $0
                            }
                        ),
                    in:
                        0...max(
                            nowPlaying.duration,
                            1
                        ),
                    onEditingChanged: {
                        editing in

                        isSeeking =
                            editing

                        onSeekInteractionChanged(
                            editing
                        )

                        if editing {

                            seekValue =
                                current

                        } else {

                            nowPlaying
                                .seek(
                                    to:
                                        seekValue
                                )
                        }
                    }
                )
                .controlSize(
                    .mini
                )
                .tint(
                    .white
                )
            }

        } else {

            Color.clear
                .frame(
                    height:
                        20
                )
        }
    }
}
