import SwiftUI

@MainActor
struct NotchView: View {

    // MARK: - Content Mode

    enum ContentMode: Equatable {
        case media
        case volume
        case brightness
    }

    let notchWidth: CGFloat
    let notchHeight: CGFloat

    // MARK: - Providers

    @StateObject
    private var nowPlaying:
        SystemNowPlayingProvider

    @StateObject
    private var hardwareHUD:
        HardwareHUDMonitor

    @ObservedObject
    private var settings:
        AppSettings

    // MARK: - Presentation

    @State
    private var expanded =
        false

    @State
    private var showContent =
        false

    @State
    private var isHovering =
        false

    @State
    private var mode:
        ContentMode = .media

    @State
    private var isManualHardwareMode =
        false

    @State
    private var closeToken =
        UUID()

    @State
    private var temporaryRevealToken =
        UUID()

    @State
    private var hardwareRevealToken =
        UUID()

    @State
    private var isHardwareInteracting =
        false

    // MARK: - Seek

    @State
    private var isSeeking =
        false

    @State
    private var seekValue:
        Double = 0

    // MARK: - Media State

    private struct MediaState:
        Equatable {

        let trackIdentity:
            String

        let isPlaying:
            Bool
    }

    // MARK: - Init

    init(
        notchWidth: CGFloat,
        notchHeight: CGFloat
    ) {

        self.notchWidth =
            notchWidth

        self.notchHeight =
            notchHeight

        self._nowPlaying =
            StateObject(
                wrappedValue:
                    SystemNowPlayingProvider()
            )

        self._hardwareHUD =
            StateObject(
                wrappedValue:
                    HardwareHUDMonitor()
            )

        self._settings =
            ObservedObject(
                wrappedValue:
                    AppSettings.shared
            )
    }

    // MARK: - Dynamic Geometry

    private var expandedWidth:
        CGFloat {

        switch mode {

        case .media:
            return 430

        case .volume,
             .brightness:
            return 360
        }
    }

    private var expandedHeight:
        CGFloat {

        switch mode {

        case .media:
            return 148

        case .volume,
             .brightness:
            return 122
        }
    }

    // MARK: - Media Info

    private var mediaState:
        MediaState {

        MediaState(
            trackIdentity:
                trackIdentity,
            isPlaying:
                nowPlaying.isPlaying
        )
    }

    private var trackIdentity:
        String {

        [
            nowPlaying.title,
            nowPlaying.artist,
            nowPlaying.album,
            String(
                Int(
                    nowPlaying.duration
                )
            )
        ]
        .joined(
            separator:
                "|"
        )
    }

    private var hasValidMedia:
        Bool {

        let title =
            nowPlaying.title
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )

        return
            !title.isEmpty
            &&
            title != "Nessun brano"
    }

    // MARK: - Body

    var body: some View {

        VStack(
            spacing: 0
        ) {

            ZStack(
                alignment:
                    .top
            ) {

                notchBackground

                if showContent {

                    displayedContent
                        .transition(
                            .opacity
                                .combined(
                                    with:
                                        .scale(
                                            scale:
                                                0.96,
                                            anchor:
                                                .top
                                        )
                                )
                        )
                }
            }
            .frame(
                width:
                    expanded
                    ? expandedWidth
                    : notchWidth,

                height:
                    expanded
                    ? expandedHeight
                    : max(
                        notchHeight,
                        32
                    ),

                alignment:
                    .top
            )
            .animation(
                .spring(
                    response:
                        0.34,
                    dampingFraction:
                        0.82
                ),
                value:
                    mode
            )
            .contentShape(
                Rectangle()
            )
            .onHover { hovering in

                handleHover(
                    hovering
                )
            }

            Spacer()
        }
        .frame(
            width:
                520,
            height:
                197
        )
        .onChange(
            of:
                mediaState
        ) { oldState, newState in

            handleMediaStateChange(
                from:
                    oldState,
                to:
                    newState
            )
        }
        .onChange(
            of:
                hardwareHUD.revision
        ) { _, _ in

            handleHardwareHUDChange()
        }
    }

    // MARK: - Content Router

    @ViewBuilder
    private var displayedContent:
        some View {

        switch mode {

        case .media:

            mediaContent
                .transition(
                    modeTransition
                )

        case .volume:

            hardwareContent(
                kind:
                    .volume
            )
            .transition(
                modeTransition
            )

        case .brightness:

            hardwareContent(
                kind:
                    .brightness
            )
            .transition(
                modeTransition
            )
        }
    }

    private var modeTransition:
        AnyTransition {

        .asymmetric(
            insertion:
                .opacity
                    .combined(
                        with:
                            .scale(
                                scale:
                                    0.96,
                                anchor:
                                    .top
                            )
                    ),

            removal:
                .opacity
                    .combined(
                        with:
                            .scale(
                                scale:
                                    0.98,
                                anchor:
                                    .top
                            )
                    )
        )
    }

    // MARK: - Background

    private var notchBackground:
        some View {

        UnevenRoundedRectangle(
            topLeadingRadius:
                0,

            bottomLeadingRadius:
                expanded
                ? 25
                : 12,

            bottomTrailingRadius:
                expanded
                ? 25
                : 12,

            topTrailingRadius:
                0,

            style:
                .continuous
        )
        .fill(
            .black
        )
        .shadow(
            color:
                expanded
                ? .black.opacity(
                    0.32
                )
                : .clear,

            radius:
                15,

            y:
                5
        )
    }

    // MARK: - Hover

    private func handleHover(
        _ hovering: Bool
    ) {

        isHovering =
            hovering

        if hovering {

            cancelScheduledClose()

            openNotch()

        } else {

            guard
                !isSeeking,
                !isHardwareInteracting
            else {
                return
            }

            isManualHardwareMode =
                false

            if mode != .media {

                hardwareHUD.clear()

                withAnimation(
                    .easeInOut(
                        duration:
                            0.18
                    )
                ) {

                    mode =
                        .media
                }
            }

            scheduleClose(
                after:
                    0.35
            )
        }
    }

    // MARK: - Media Content

    private var mediaContent:
        some View {

        VStack(
            spacing:
                9
        ) {

            HStack(
                spacing:
                    12
            ) {

                artworkView

                mediaInformation

                Spacer(
                    minLength:
                        8
                )

                controlsView
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
            .top,
            notchHeight
        )
        .padding(
            .bottom,
            8
        )
    }

    // MARK: - Media Information

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
                .id(
                    "title-\(trackIdentity)"
                )
                .transition(
                    .opacity
                        .combined(
                            with:
                                .offset(
                                    y:
                                        4
                                )
                        )
                )
            }

            Text(
                nowPlaying.artist
            )
            .font(
                .system(
                    size:
                        11,
                    weight:
                        .regular
                )
            )
            .foregroundStyle(
                .secondary
            )
            .lineLimit(
                1
            )
            .id(
                "artist-\(trackIdentity)"
            )
            .transition(
                .opacity
            )
        }
        .frame(
            maxWidth:
                155,
            alignment:
                .leading
        )
        .animation(
            .easeOut(
                duration:
                    0.20
            ),
            value:
                trackIdentity
        )
    }

    // MARK: - Artwork

    private var artworkView:
        some View {

        ZStack {

            RoundedRectangle(
                cornerRadius:
                    10,
                style:
                    .continuous
            )
            .fill(
                Color.white
                    .opacity(
                        0.07
                    )
            )

            if let artwork =
                nowPlaying.artwork {

                Image(
                    nsImage:
                        artwork
                )
                .resizable()
                .scaledToFill()
                .id(
                    "artwork-\(trackIdentity)"
                )
                .transition(
                    .opacity
                        .combined(
                            with:
                                .scale(
                                    scale:
                                        0.90
                                )
                        )
                )

            } else {

                Image(
                    systemName:
                        "music.note"
                )
                .font(
                    .system(
                        size:
                            18,
                        weight:
                            .medium
                    )
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .frame(
            width:
                50,
            height:
                50
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius:
                    10,
                style:
                    .continuous
            )
        )
        .animation(
            .spring(
                response:
                    0.30,
                dampingFraction:
                    0.86
            ),
            value:
                trackIdentity
        )
    }

    // MARK: - Player Controls

    private var controlsView:
        some View {

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

                ZStack {

                    Circle()
                        .fill(
                            Color.white
                                .opacity(
                                    nowPlaying.isPlaying
                                    ? 0.16
                                    : 0.12
                                )
                        )

                    Image(
                        systemName:
                            nowPlaying.isPlaying
                            ? "pause.fill"
                            : "play.fill"
                    )
                    .font(
                        .system(
                            size:
                                13,
                            weight:
                                .bold
                        )
                    )
                    .contentTransition(
                        .symbolEffect(
                            .replace
                        )
                    )
                }
                .frame(
                    width:
                        34,
                    height:
                        34
                )
                .scaleEffect(
                    nowPlaying.isPlaying
                    ? 1.0
                    : 0.98
                )
                .animation(
                    .spring(
                        response:
                            0.25,
                        dampingFraction:
                            0.80
                    ),
                    value:
                        nowPlaying.isPlaying
                )
            }
            .help(
                nowPlaying.isPlaying
                ? "Pausa"
                : "Riproduci"
            )

            playerButton(
                icon:
                    "forward.fill"
            ) {

                nowPlaying
                    .nextTrack()
            }
        }
    }

    private func playerButton(
        icon: String,
        action: @escaping () -> Void
    ) -> some View {

        Button(
            action:
                action
        ) {

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
            .frame(
                width:
                    24,
                height:
                    24
            )
            .contentShape(
                Circle()
            )
        }
    }

    // MARK: - Seek Section

    private var seekSection:
        some View {

        HStack(
            spacing:
                8
        ) {

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

                    let displayTime =
                        isSeeking
                        ? seekValue
                        : current

                    VStack(
                        spacing:
                            2
                    ) {

                        Slider(
                            value:
                                Binding(
                                    get: {

                                        isSeeking
                                        ? seekValue
                                        : current
                                    },

                                    set: { value in

                                        seekValue =
                                            value
                                    }
                                ),

                            in:
                                0...max(
                                    nowPlaying.duration,
                                    1
                                ),

                            onEditingChanged: { editing in

                                if editing {

                                    cancelScheduledClose()

                                    isSeeking =
                                        true

                                    seekValue =
                                        current

                                } else {

                                    isSeeking =
                                        false

                                    nowPlaying
                                        .seek(
                                            to:
                                                seekValue
                                        )

                                    if !isHovering {

                                        scheduleClose(
                                            after:
                                                0.45
                                        )
                                    }
                                }
                            }
                        )
                        .controlSize(
                            .mini
                        )
                        .tint(
                            .white
                        )

                        HStack {

                            Text(
                                formatTime(
                                    displayTime
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
                                size:
                                    9,
                                weight:
                                    .medium,
                                design:
                                    .rounded
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .monospacedDigit()
                    }
                }
                .frame(
                    maxWidth:
                        .infinity
                )

            } else {

                Spacer()
            }

            hardwareButtons
        }
    }

    // MARK: - Fixed Hardware Buttons

    private var hardwareButtons:
        some View {

        HStack(
            spacing:
                6
        ) {

            Button {

                showVolumeMode()

            } label: {

                fixedHardwareButton(
                    systemImage:
                        "speaker.wave.2.fill"
                )
            }
            .help(
                "Volume"
            )

            Button {

                showBrightnessMode()

            } label: {

                fixedHardwareButton(
                    systemImage:
                        "sun.max.fill"
                )
            }
            .help(
                "Luminosità"
            )
        }
        .buttonStyle(
            .plain
        )
    }

    private func fixedHardwareButton(
        systemImage: String
    ) -> some View {

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
                        0.09
                    )
            )

            Image(
                systemName:
                    systemImage
            )
            .font(
                .system(
                    size:
                        11,
                    weight:
                        .semibold
                )
            )
        }
        .frame(
            width:
                30,
            height:
                26
        )
        .contentShape(
            RoundedRectangle(
                cornerRadius:
                    8
            )
        )
    }

    // MARK: - Hardware Content

    private func hardwareContent(
        kind:
            HardwareHUDMonitor.Kind
    ) -> some View {

        let presentation =
            hardwareHUD.presentation

        let value =
            presentation?.value
            ?? 0

        let isVolume =
            kind == .volume

        let title =
            isVolume
            ? "Volume"
            : "Luminosità"

        let fallbackIcon =
            isVolume
            ? "speaker.wave.2.fill"
            : "sun.max.fill"

        let icon =
            presentation?.systemImage
            ?? fallbackIcon

        return VStack(
            spacing:
                11
        ) {

            HStack(
                spacing:
                    12
            ) {

                hardwareMainButton(
                    kind:
                        kind,
                    icon:
                        icon
                )

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        2
                ) {

                    Text(
                        title
                    )
                    .font(
                        .system(
                            size:
                                14,
                            weight:
                                .semibold
                        )
                    )

                    Text(
                        "\(Int((value * 100).rounded()))%"
                    )
                    .font(
                        .system(
                            size:
                                11,
                            weight:
                                .medium
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .contentTransition(
                        .numericText()
                    )
                }

                Spacer()

                returnButton
            }

            Slider(
                value:
                    Binding(
                        get: {

                            hardwareHUD
                                .presentation?
                                .value
                            ?? 0
                        },

                        set: { newValue in

                            hardwareHUD
                                .setCurrentValue(
                                    newValue
                                )
                        }
                    ),

                in:
                    0...1,

                onEditingChanged: { editing in

                    handleHardwareSliderInteraction(
                        editing
                    )
                }
            )
            .controlSize(
                .small
            )
            .tint(
                .white
            )
        }
        .foregroundStyle(
            .white
        )
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
            9
        )
    }

    // MARK: - Hardware Main Button

    private func hardwareMainButton(
        kind:
            HardwareHUDMonitor.Kind,
        icon:
            String
    ) -> some View {

        Button {

            if kind == .volume {

                hardwareHUD
                    .toggleMute()
            }

        } label: {

            ZStack {

                RoundedRectangle(
                    cornerRadius:
                        12,
                    style:
                        .continuous
                )
                .fill(
                    Color.white
                        .opacity(
                            0.10
                        )
                )

                Image(
                    systemName:
                        icon
                )
                .font(
                    .system(
                        size:
                            18,
                        weight:
                            .semibold
                    )
                )
                .contentTransition(
                    .symbolEffect(
                        .replace
                    )
                )
            }
            .frame(
                width:
                    44,
                height:
                    44
            )
        }
        .buttonStyle(
            .plain
        )
        .disabled(
            kind != .volume
        )
        .help(
            kind == .volume
            ? "Mute / Unmute"
            : "Luminosità"
        )
    }

    // MARK: - Return Button

    private var returnButton:
        some View {

        Button {

            returnToMedia()

        } label: {

            ZStack {

                Circle()
                    .fill(
                        Color.white
                            .opacity(
                                0.09
                            )
                    )

                Image(
                    systemName:
                        "chevron.left"
                )
                .font(
                    .system(
                        size:
                            11,
                        weight:
                            .bold
                    )
                )
            }
            .frame(
                width:
                    30,
                height:
                    30
            )
        }
        .buttonStyle(
            .plain
        )
        .help(
            "Torna al player"
        )
    }

    // MARK: - Hardware Mode Selection

    private func showVolumeMode() {

        isManualHardwareMode =
            true

        hardwareRevealToken =
            UUID()

        hardwareHUD
            .showVolume()

        switchMode(
            to:
                .volume
        )

        openNotch()
    }

    private func showBrightnessMode() {

        isManualHardwareMode =
            true

        hardwareRevealToken =
            UUID()

        hardwareHUD
            .showBrightness()

        switchMode(
            to:
                .brightness
        )

        openNotch()
    }

    private func returnToMedia() {

        isManualHardwareMode =
            false

        hardwareRevealToken =
            UUID()

        hardwareHUD.clear()

        switchMode(
            to:
                .media
        )
    }

    private func switchMode(
        to newMode:
            ContentMode
    ) {

        guard mode != newMode else {
            return
        }

        withAnimation(
            .spring(
                response:
                    0.30,
                dampingFraction:
                    0.86
            )
        ) {

            mode =
                newMode
        }
    }

    // MARK: - Hardware Slider

    private func handleHardwareSliderInteraction(
        _ editing: Bool
    ) {

        isHardwareInteracting =
            editing

        if editing {

            cancelScheduledClose()

            hardwareRevealToken =
                UUID()

            openNotch()

        } else if !isManualHardwareMode {

            scheduleHardwareDismiss(
                after:
                    1.0
            )
        }
    }

    // MARK: - Hardware Auto Reveal

    private func handleHardwareHUDChange() {

        guard
            let presentation =
                hardwareHUD.presentation
        else {
            return
        }

        guard
            !isManualHardwareMode
        else {
            return
        }

        switch presentation.kind {

        case .volume:

            switchMode(
                to:
                    .volume
            )

        case .brightness:

            switchMode(
                to:
                    .brightness
            )
        }

        openNotch()

        scheduleHardwareDismiss(
            after:
                1.25
        )
    }

    private func scheduleHardwareDismiss(
        after delay:
            TimeInterval
    ) {

        let token =
            UUID()

        hardwareRevealToken =
            token

        DispatchQueue.main.asyncAfter(
            deadline:
                .now()
                + delay
        ) {

            guard
                hardwareRevealToken
                    == token
            else {
                return
            }

            guard
                !isManualHardwareMode,
                !isHardwareInteracting
            else {
                return
            }

            hardwareHUD.clear()

            switchMode(
                to:
                    .media
            )

            if !isHovering {

                closeNotch()
            }
        }
    }

    // MARK: - Media Auto Reveal

    private func handleMediaStateChange(
        from oldState:
            MediaState,
        to newState:
            MediaState
    ) {

        guard hasValidMedia else {
            return
        }

        let trackChanged =
            oldState.trackIdentity
            != newState.trackIdentity

        let playbackStarted =
            !oldState.isPlaying
            &&
            newState.isPlaying

        if
            trackChanged,
            settings.revealOnTrackChange {

            revealTemporarily()

            return
        }

        if
            playbackStarted,
            settings.revealOnPlaybackStart {

            revealTemporarily()
        }
    }

    private func revealTemporarily() {

        let token =
            UUID()

        temporaryRevealToken =
            token

        openNotch()

        DispatchQueue.main.asyncAfter(
            deadline:
                .now()
                + settings.mediaRevealDuration
        ) {

            guard
                temporaryRevealToken
                    == token
            else {
                return
            }

            guard
                !isHovering,
                !isSeeking,
                !isManualHardwareMode,
                !isHardwareInteracting
            else {
                return
            }

            closeNotch()
        }
    }

    // MARK: - Close Scheduling

    private func scheduleClose(
        after delay:
            TimeInterval
    ) {

        let token =
            UUID()

        closeToken =
            token

        DispatchQueue.main.asyncAfter(
            deadline:
                .now()
                + delay
        ) {

            guard
                closeToken
                    == token
            else {
                return
            }

            guard
                !isHovering,
                !isSeeking,
                !isHardwareInteracting
            else {
                return
            }

            closeNotch()
        }
    }

    private func cancelScheduledClose() {

        closeToken =
            UUID()
    }

    // MARK: - Open

    private func openNotch() {

        cancelScheduledClose()

        if expanded {

            if !showContent {

                withAnimation(
                    .easeOut(
                        duration:
                            0.16
                    )
                ) {

                    showContent =
                        true
                }
            }

            return
        }

        withAnimation(
            .spring(
                response:
                    0.33,
                dampingFraction:
                    0.80,
                blendDuration:
                    0.1
            )
        ) {

            expanded =
                true
        }

        DispatchQueue.main.asyncAfter(
            deadline:
                .now()
                + 0.07
        ) {

            guard expanded else {
                return
            }

            withAnimation(
                .easeOut(
                    duration:
                        0.17
                )
            ) {

                showContent =
                    true
            }
        }
    }

    // MARK: - Close

    private func closeNotch() {

        guard
            !isHovering,
            !isSeeking,
            !isHardwareInteracting
        else {
            return
        }

        guard expanded else {
            return
        }

        isManualHardwareMode =
            false

        hardwareHUD.clear()

        withAnimation(
            .easeOut(
                duration:
                    0.10
            )
        ) {

            showContent =
                false
        }

        DispatchQueue.main.asyncAfter(
            deadline:
                .now()
                + 0.06
        ) {

            guard
                !showContent,
                !isHovering,
                !isSeeking,
                !isHardwareInteracting
            else {
                return
            }

            mode =
                .media

            withAnimation(
                .spring(
                    response:
                        0.32,
                    dampingFraction:
                        0.85
                )
            ) {

                expanded =
                    false
            }
        }
    }

    // MARK: - Time Formatting

    private func formatTime(
        _ seconds: Double
    ) -> String {

        guard
            seconds.isFinite,
            seconds >= 0
        else {
            return "0:00"
        }

        let total =
            Int(
                seconds
            )

        let minutes =
            total / 60

        let remainingSeconds =
            total % 60

        return String(
            format:
                "%d:%02d",
            minutes,
            remainingSeconds
        )
    }
}
