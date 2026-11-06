import SwiftUI

@MainActor
struct NotchView: View {

    // MARK: - Content Mode

    enum ContentMode: Equatable {
        case media
        case volume
        case brightness
        case timer
        case more
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

    @StateObject
    private var timerController:
        NotchTimerController

    @ObservedObject
    private var settings:
        AppSettings

    // MARK: - Presentation

    @State
    private var expanded = false

    @State
    private var showContent = false

    @State
    private var isHovering = false

    @State
    private var mode:
        ContentMode = .media

    @State
    private var isManualHardwareMode = false

    @State
    private var closeToken = UUID()

    @State
    private var temporaryRevealToken = UUID()

    @State
    private var hardwareRevealToken = UUID()

    @State
    private var isHardwareInteracting = false

    // MARK: - Seek

    @State
    private var isSeeking = false

    @State
    private var seekValue:
        Double = 0

    // MARK: - Timer

    @State
    private var selectedTimerMinutes = 5

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

        self._timerController =
            StateObject(
                wrappedValue:
                    NotchTimerController()
            )

        self._settings =
            ObservedObject(
                wrappedValue:
                    AppSettings.shared
            )
    }

    // MARK: - Geometry

    private var expandedWidth:
        CGFloat {

        switch mode {

        case .media:
            return 440

        case .volume,
             .brightness:
            return 390

        case .timer:
            return 410

        case .more:
            return 390
        }
    }

    private var expandedHeight:
        CGFloat {

        switch mode {

        case .media:
            return 170

        case .volume,
             .brightness:
            return 148

        case .timer:
            return 182

        case .more:
            return 145
        }
    }

    // MARK: - Media

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

                    VStack(
                        spacing: 0
                    ) {

                        featureRail

                        contentArea
                    }
                    .transition(
                        .opacity
                            .combined(
                                with:
                                    .scale(
                                        scale:
                                            0.97,
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
                210
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
        .onChange(
            of:
                timerController.isFinished
        ) { _, finished in

            if finished {
                handleTimerFinished()
            }
        }
    }

    // MARK: - Background

    private var notchBackground:
        some View {

        UnevenRoundedRectangle(
            topLeadingRadius:
                0,

            bottomLeadingRadius:
                expanded
                ? 26
                : 12,

            bottomTrailingRadius:
                expanded
                ? 26
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

    // MARK: - Feature Rail

    private var featureRail:
        some View {

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
                    timerController.isRunning
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
        .padding(
            .horizontal,
            14
        )
        .padding(
            .top,
            notchHeight + 4
        )
        .padding(
            .bottom,
            7
        )
    }

    private func featureTab(
        mode tabMode:
            ContentMode,
        icon:
            String
    ) -> some View {

        let selected =
            mode == tabMode

        return Button {

            selectMode(
                tabMode
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

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea:
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

        case .timer:

            timerContent
                .transition(
                    modeTransition
                )

        case .more:

            moreContent
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
                                    0.97,
                                anchor:
                                    .top
                            )
                    ),

            removal:
                .opacity
        )
    }

    // MARK: - Mode Selection

    private func selectMode(
        _ newMode:
            ContentMode
    ) {

        cancelScheduledClose()

        hardwareRevealToken =
            UUID()

        switch newMode {

        case .media:

            isManualHardwareMode =
                false

            hardwareHUD.clear()

        case .volume:

            isManualHardwareMode =
                true

            hardwareHUD
                .showVolume()

        case .brightness:

            isManualHardwareMode =
                true

            hardwareHUD
                .showBrightness()

        case .timer:

            isManualHardwareMode =
                false

            hardwareHUD.clear()

        case .more:

            isManualHardwareMode =
                false

            hardwareHUD.clear()
        }

        switchMode(
            to:
                newMode
        )

        openNotch()
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

            hardwareHUD.clear()

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
            .bottom,
            10
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

            } else {

                Image(
                    systemName:
                        "music.note"
                )
                .font(
                    .system(
                        size:
                            18
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
                                    0.14
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
        }
    }

    // MARK: - Seek

    private var seekSection:
        some View {

        Group {

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

            } else {

                Color.clear
                    .frame(
                        height:
                            20
                    )
            }
        }
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
            .bottom,
            12
        )
    }

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
    }

    // MARK: - Timer Content

    private var timerContent:
        some View {

        VStack(
            spacing:
                10
        ) {

            HStack(
                spacing:
                    12
            ) {

                timerIcon

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        2
                ) {

                    Text(
                        timerController.isFinished
                        ? "Timer terminato"
                        : "Timer"
                    )
                    .font(
                        .system(
                            size:
                                14,
                            weight:
                                .semibold
                        )
                    )

                    if timerController.totalSeconds > 0 {

                        Text(
                            timerController
                                .formattedRemainingTime
                        )
                        .font(
                            .system(
                                size:
                                    20,
                                weight:
                                    .semibold,
                                design:
                                    .rounded
                            )
                        )
                        .monospacedDigit()

                    } else {

                        Text(
                            "\(selectedTimerMinutes) min"
                        )
                        .font(
                            .system(
                                size:
                                    17,
                                weight:
                                    .semibold,
                                design:
                                    .rounded
                            )
                        )
                    }
                }

                Spacer()
            }

            if timerController.totalSeconds > 0 {

                timerRunningControls

            } else {

                timerSetupControls
            }
        }
        .foregroundStyle(
            .white
        )
        .padding(
            .horizontal,
            22
        )
        .padding(
            .bottom,
            12
        )
    }

    private var timerIcon:
        some View {

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
                        timerController.isFinished
                        ? 0.18
                        : 0.10
                    )
            )

            Image(
                systemName:
                    timerController.isFinished
                    ? "bell.fill"
                    : "timer"
            )
            .font(
                .system(
                    size:
                        19,
                    weight:
                        .semibold
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

    // MARK: - Timer Setup

    private var timerSetupControls:
        some View {

        VStack(
            spacing:
                8
        ) {

            HStack(
                spacing:
                    6
            ) {

                timerPresetButton(
                    minutes:
                        5
                )

                timerPresetButton(
                    minutes:
                        10
                )

                timerPresetButton(
                    minutes:
                        15
                )

                timerPresetButton(
                    minutes:
                        25
                )
            }

            HStack(
                spacing:
                    10
            ) {

                Button {

                    selectedTimerMinutes =
                        max(
                            selectedTimerMinutes - 1,
                            1
                        )

                } label: {

                    Image(
                        systemName:
                            "minus"
                    )
                    .frame(
                        width:
                            26,
                        height:
                            24
                    )
                    .background(
                        Color.white
                            .opacity(
                                0.09
                            )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius:
                                7
                        )
                    )
                }

                Text(
                    "\(selectedTimerMinutes) min"
                )
                .font(
                    .system(
                        size:
                            12,
                        weight:
                            .semibold,
                        design:
                            .rounded
                    )
                )
                .frame(
                    minWidth:
                        52
                )

                Button {

                    selectedTimerMinutes =
                        min(
                            selectedTimerMinutes + 1,
                            120
                        )

                } label: {

                    Image(
                        systemName:
                            "plus"
                    )
                    .frame(
                        width:
                            26,
                        height:
                            24
                    )
                    .background(
                        Color.white
                            .opacity(
                                0.09
                            )
                    )
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius:
                                7
                        )
                    )
                }

                Spacer()

                Button {

                    timerController
                        .start(
                            minutes:
                                selectedTimerMinutes
                        )

                } label: {

                    Label(
                        "Avvia",
                        systemImage:
                            "play.fill"
                    )
                    .font(
                        .system(
                            size:
                                11,
                            weight:
                                .semibold
                        )
                    )
                    .padding(
                        .horizontal,
                        12
                    )
                    .frame(
                        height:
                            26
                    )
                    .background(
                        Color.white
                            .opacity(
                                0.16
                            )
                    )
                    .clipShape(
                        Capsule()
                    )
                }
            }
        }
        .buttonStyle(
            .plain
        )
    }

    private func timerPresetButton(
        minutes: Int
    ) -> some View {

        Button {

            selectedTimerMinutes =
                minutes

        } label: {

            Text(
                "\(minutes)m"
            )
            .font(
                .system(
                    size:
                        10,
                    weight:
                        .semibold
                )
            )
            .frame(
                maxWidth:
                    .infinity
            )
            .frame(
                height:
                    24
            )
            .background(
                Color.white
                    .opacity(
                        selectedTimerMinutes == minutes
                        ? 0.18
                        : 0.07
                    )
            )
            .clipShape(
                Capsule()
            )
        }
        .buttonStyle(
            .plain
        )
    }

    // MARK: - Timer Running

    private var timerRunningControls:
        some View {

        VStack(
            spacing:
                8
        ) {

            ProgressView(
                value:
                    timerController.progress,
                total:
                    1
            )
            .progressViewStyle(
                .linear
            )
            .tint(
                .white
            )

            HStack {

                if timerController.isFinished {

                    Button {

                        timerController
                            .reset()

                    } label: {

                        Label(
                            "Nuovo timer",
                            systemImage:
                                "arrow.counterclockwise"
                        )
                    }

                } else {

                    Button {

                        if timerController.isRunning {

                            timerController
                                .pause()

                        } else {

                            timerController
                                .resume()
                        }

                    } label: {

                        Label(
                            timerController.isRunning
                            ? "Pausa"
                            : "Riprendi",

                            systemImage:
                                timerController.isRunning
                                ? "pause.fill"
                                : "play.fill"
                        )
                    }

                    Spacer()

                    Button {

                        timerController
                            .reset()

                    } label: {

                        Label(
                            "Annulla",
                            systemImage:
                                "xmark"
                        )
                    }
                }
            }
            .font(
                .system(
                    size:
                        10,
                    weight:
                        .semibold
                )
            )
            .buttonStyle(
                .plain
            )
        }
    }

    // MARK: - More

    private var moreContent:
        some View {

        VStack(
            spacing:
                8
        ) {

            Image(
                systemName:
                    "ellipsis.circle"
            )
            .font(
                .system(
                    size:
                        24
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                "Altre funzioni"
            )
            .font(
                .system(
                    size:
                        13,
                    weight:
                        .semibold
                )
            )

            Text(
                "Qui aggiungeremo le prossime feature."
            )
            .font(
                .system(
                    size:
                        10
                )
            )
            .foregroundStyle(
                .secondary
            )
        }
        .foregroundStyle(
            .white
        )
        .frame(
            maxWidth:
                .infinity
        )
        .padding(
            .bottom,
            12
        )
    }

    // MARK: - Switch

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
                .now() + delay
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

    // MARK: - Timer Finished

    private func handleTimerFinished() {

        guard
            timerController.isFinished
        else {
            return
        }

        switchMode(
            to:
                .timer
        )

        openNotch()

        let token =
            UUID()

        temporaryRevealToken =
            token

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 5
        ) {

            guard
                temporaryRevealToken
                    == token
            else {
                return
            }

            if !isHovering {
                closeNotch()
            }
        }
    }

    // MARK: - Media Reveal

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

        switchMode(
            to:
                .media
        )

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

    // MARK: - Close

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
                .now() + delay
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
                    0.80
            )
        ) {

            expanded =
                true
        }

        DispatchQueue.main.asyncAfter(
            deadline:
                .now() + 0.07
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
                .now() + 0.06
        ) {

            guard
                !showContent,
                !isHovering
            else {
                return
            }

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

    // MARK: - Time

    private func formatTime(
        _ seconds:
            Double
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

        let remaining =
            total % 60

        return String(
            format:
                "%d:%02d",
            minutes,
            remaining
        )
    }
}
