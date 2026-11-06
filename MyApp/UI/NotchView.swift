import SwiftUI

struct NotchView: View {

    let notchWidth: CGFloat
    let notchHeight: CGFloat

    @StateObject private var nowPlaying =
        SystemNowPlayingProvider()

    @State private var expanded = false
    @State private var showContent = false

    @State private var isSeeking = false
    @State private var seekValue: Double = 0

    var body: some View {

        VStack(spacing: 0) {

            ZStack(alignment: .top) {

                notchBackground

                if showContent {

                    expandedContent
                        .transition(
                            .opacity
                                .combined(
                                    with:
                                        .scale(
                                            scale: 0.96,
                                            anchor: .top
                                        )
                                )
                                .combined(
                                    with:
                                        .offset(
                                            y: -4
                                        )
                                )
                        )
                }
            }
            .frame(
                width:
                    expanded
                    ? 420
                    : notchWidth,

                height:
                    expanded
                    ? 132
                    : max(
                        notchHeight,
                        32
                    ),

                alignment: .top
            )
            .contentShape(
                Rectangle()
            )
            .onHover { hovering in

                if hovering {
                    openNotch()
                } else if !isSeeking {
                    closeNotch()
                }
            }

            Spacer()
        }
        .frame(
            width: 520,
            height: 197
        )
    }

    // MARK: - Background

    private var notchBackground: some View {

        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius:
                expanded ? 26 : 12,
            bottomTrailingRadius:
                expanded ? 26 : 12,
            topTrailingRadius: 0,
            style: .continuous
        )
        .fill(.black)
        .shadow(
            color:
                expanded
                ? .black.opacity(0.25)
                : .clear,
            radius: 12,
            y: 4
        )
    }

    // MARK: - Content

    private var expandedContent: some View {

        VStack(spacing: 10) {

            HStack(spacing: 14) {

                artworkView

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    HStack(spacing: 6) {

                        if let playerIcon =
                            nowPlaying.playerIcon {

                            Image(
                                nsImage: playerIcon
                            )
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: 14,
                                height: 14
                            )
                        }

                        Text(
                            nowPlaying.title
                        )
                        .font(.headline)
                        .lineLimit(1)
                    }

                    Text(
                        nowPlaying.artist
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .gray
                    )
                    .lineLimit(1)
                }

                Spacer()

                controlsView
            }

            if nowPlaying.duration > 0 {
                seekView
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(
            .horizontal,
            22
        )
        .padding(
            .top,
            notchHeight
        )
        .padding(
            .bottom,
            7
        )
    }

    // MARK: - Controls

    private var controlsView: some View {

        HStack(spacing: 14) {

            Button {
                nowPlaying.previousTrack()
            } label: {

                Image(
                    systemName:
                        "backward.fill"
                )
            }

            Button {
                nowPlaying.togglePlayback()
            } label: {

                Image(
                    systemName:
                        nowPlaying.isPlaying
                        ? "pause.fill"
                        : "play.fill"
                )
            }

            Button {
                nowPlaying.nextTrack()
            } label: {

                Image(
                    systemName:
                        "forward.fill"
                )
            }
        }
        .font(
            .system(
                size: 14
            )
        )
    }

    // MARK: - Seek

    private var seekView: some View {

        TimelineView(
            .periodic(
                from: .now,
                by: 0.25
            )
        ) { _ in

            let current =
                nowPlaying.currentElapsedTime()

            let displayedTime =
                isSeeking
                ? seekValue
                : current

            VStack(spacing: 3) {

                Slider(
                    value: Binding(
                        get: {
                            isSeeking
                            ? seekValue
                            : current
                        },
                        set: { newValue in
                            seekValue = newValue
                        }
                    ),
                    in: 0...max(
                        nowPlaying.duration,
                        1
                    ),
                    onEditingChanged: {
                        editing in

                        if editing {

                            isSeeking = true
                            seekValue = current

                        } else {

                            isSeeking = false

                            nowPlaying.seek(
                                to: seekValue
                            )
                        }
                    }
                )
                .controlSize(.mini)

                HStack {

                    Text(
                        formatTime(
                            displayedTime
                        )
                    )

                    Spacer()

                    Text(
                        formatTime(
                            nowPlaying.duration
                        )
                    )
                }
                .font(
                    .system(
                        size: 10,
                        weight: .medium,
                        design: .rounded
                    )
                )
                .foregroundStyle(
                    .gray
                )
            }
        }
    }

    // MARK: - Artwork

    private var artworkView: some View {

        Group {

            if let artwork =
                nowPlaying.artwork {

                Image(
                    nsImage: artwork
                )
                .resizable()
                .scaledToFill()

            } else {

                ZStack {

                    RoundedRectangle(
                        cornerRadius: 8
                    )
                    .fill(
                        Color.gray
                            .opacity(0.25)
                    )

                    Image(
                        systemName:
                            "music.note"
                    )
                    .foregroundStyle(
                        .white
                    )
                }
            }
        }
        .frame(
            width: 50,
            height: 50
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 8,
                style: .continuous
            )
        )
    }

    // MARK: - Animation

    private func openNotch() {

        guard !expanded else {
            return
        }

        withAnimation(
            .spring(
                response: 0.32,
                dampingFraction: 0.78,
                blendDuration: 0.1
            )
        ) {
            expanded = true
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.08
        ) {

            guard expanded else {
                return
            }

            withAnimation(
                .easeOut(
                    duration: 0.18
                )
            ) {
                showContent = true
            }
        }
    }

    private func closeNotch() {

        guard expanded else {
            return
        }

        withAnimation(
            .easeOut(
                duration: 0.10
            )
        ) {
            showContent = false
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + 0.06
        ) {

            guard !showContent else {
                return
            }

            withAnimation(
                .spring(
                    response: 0.32,
                    dampingFraction: 0.84,
                    blendDuration: 0.1
                )
            ) {
                expanded = false
            }
        }
    }

    // MARK: - Time

    private func formatTime(
        _ seconds: Double
    ) -> String {

        guard
            seconds.isFinite,
            seconds >= 0
        else {
            return "0:00"
        }

        let totalSeconds =
            Int(seconds)

        let minutes =
            totalSeconds / 60

        let remainingSeconds =
            totalSeconds % 60

        return String(
            format:
                "%d:%02d",
            minutes,
            remainingSeconds
        )
    }
}
