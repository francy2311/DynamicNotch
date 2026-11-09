import SwiftUI

@MainActor
struct MediaControlsView: View {

    @ObservedObject
    var nowPlaying:
        SystemNowPlayingProvider

    var body: some View {

        HStack(
            spacing:
                10
        ) {

            playerButton(
                icon:
                    "backward.fill"
            ) {

                nowPlaying
                    .previousTrack()
            }

            Button {

                nowPlaying
                    .togglePlayback()

            } label: {

                Image(
                    systemName:
                        nowPlaying.isPlaying
                        ? "pause.fill"
                        : "play.fill"
                )
                .frame(
                    width:
                        34,
                    height:
                        34
                )
                .background(
                    Color.white
                        .opacity(
                            0.14
                        )
                )
                .clipShape(
                    Circle()
                )
            }

            playerButton(
                icon:
                    "forward.fill"
            ) {

                nowPlaying
                    .nextTrack()
            }
        }
    }

    // MARK: - Button

    private func playerButton(
        icon:
            String,
        action:
            @escaping () -> Void
    ) -> some View {

        Button(
            action:
                action
        ) {

            Image(
                systemName:
                    icon
            )
            .frame(
                width:
                    24,
                height:
                    24
            )
        }
    }
}
