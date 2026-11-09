import SwiftUI
import AppKit

@MainActor
struct NotchView: View {

    // MARK: - Main Mode

    enum ContentMode:
        Equatable {

        case media
        case volume
        case brightness
        case timer
        case more
    }

    // MARK: - Overflow

    enum OverflowMode:
        Equatable {

        case clipboard
        case shelf
        case agenda
        case battery
    }

    // MARK: - Geometry

    let notchWidth:
        CGFloat

    let notchHeight:
        CGFloat

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

    @StateObject
    private var clipboardManager:
        ClipboardManager

    @StateObject
    private var shelfManager:
        FileShelfManager

    @StateObject
    private var batteryMonitor:
        BatteryMonitor

    @StateObject
    private var calendarMonitor:
        CalendarMonitor

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
    private var overflowMode:
        OverflowMode = .clipboard

    // MARK: - Interaction

    @State
    private var isSeeking =
        false

    @State
    private var isHardwareInteracting =
        false

    @State
    private var isManualHardwareMode =
        false

    // MARK: - Tokens

    @State
    private var closeToken =
        UUID()

    @State
    private var temporaryRevealToken =
        UUID()

    @State
    private var hardwareRevealToken =
        UUID()

    // MARK: - Configuration

    private let normalCloseDelay:
        TimeInterval = 0.35

    private let shelfCloseDelay:
        TimeInterval = 2.5

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
        notchWidth:
            CGFloat,
        notchHeight:
            CGFloat
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

        self._clipboardManager =
            StateObject(
                wrappedValue:
                    ClipboardManager()
            )

        self._shelfManager =
            StateObject(
                wrappedValue:
                    FileShelfManager()
            )

        self._batteryMonitor =
            StateObject(
                wrappedValue:
                    BatteryMonitor()
            )

        self._calendarMonitor =
            StateObject(
                wrappedValue:
                    CalendarMonitor()
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

            return 440
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

            switch overflowMode {

            case .clipboard:

                return 275

            case .shelf:

                return 275

            case .agenda:

                return 255

            case .battery:

                return 210
            }
        }
    }

    // MARK: - Special Modes

    private var isClipboardPinned:
        Bool {

        mode == .more
        &&
        overflowMode == .clipboard
    }

    private var isShelfActive:
        Bool {

        mode == .more
        &&
        overflowMode == .shelf
    }

    // MARK: - Media State

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

    var body:
        some View {

        VStack(
            spacing:
                0
        ) {

            ZStack(
                alignment:
                    .top
            ) {

                notchBackground

                if showContent {

                    VStack(
                        spacing:
                            0
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
            .animation(
                .spring(
                    response:
                        0.30,
                    dampingFraction:
                        0.86
                ),
                value:
                    overflowMode
            )
            .contentShape(
                Rectangle()
            )
            .onHover {
                hovering in

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
                300
        )
        .onChange(
            of:
                mediaState
        ) {
            oldState,
            newState in

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

        FeatureRailView(
            selectedMode:
                mode,

            isTimerRunning:
                timerController.isRunning,

            onSelect:
                selectMode
        )
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

    // MARK: - Content

    @ViewBuilder
    private var contentArea:
        some View {

        switch mode {

        case .media:

            MediaView(
                nowPlaying:
                    nowPlaying,
                onSeekInteractionChanged:
                    handleSeekInteraction
            )

        case .volume:

            HardwareView(
                hardwareHUD:
                    hardwareHUD,
                kind:
                    .volume,
                onInteractionChanged:
                    handleHardwareSliderInteraction
            )

        case .brightness:

            HardwareView(
                hardwareHUD:
                    hardwareHUD,
                kind:
                    .brightness,
                onInteractionChanged:
                    handleHardwareSliderInteraction
            )

        case .timer:

            TimerView(
                timerController:
                    timerController
            )

        case .more:

            overflowContent
        }
    }

    // MARK: - Overflow

    private var overflowContent:
        some View {

        VStack(
            spacing:
                8
        ) {

            OverflowNavigationView(
                selectedMode:
                    overflowMode,

                batterySystemImage:
                    batteryMonitor.systemImage,

                onSelect:
                    selectOverflowMode
            )

            Group {

                switch overflowMode {

                case .clipboard:

                    ClipboardView(
                        clipboardManager:
                            clipboardManager
                    )

                case .shelf:

                    FileShelfView(
                        shelfManager:
                            shelfManager,
                        onActivity:
                            handleShelfActivity
                    )

                case .agenda:

                    AgendaView(
                        calendarMonitor:
                            calendarMonitor
                    )

                case .battery:

                    BatteryView(
                        batteryMonitor:
                            batteryMonitor
                    )
                }
            }
            .transition(
                .opacity
            )
        }
    }

    // MARK: - Main Mode

    private func selectMode(
        _ newMode:
            ContentMode
    ) {

        cancelScheduledClose()

        hardwareRevealToken =
            UUID()

        switch newMode {

        case .media,
             .timer,
             .more:

            isManualHardwareMode =
                false

            hardwareHUD
                .clear()

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
        }

        switchMode(
            to:
                newMode
        )

        openNotch()
    }

    private func switchMode(
        to newMode:
            ContentMode
    ) {

        withAnimation {

            mode =
                newMode
        }
    }

    // MARK: - Overflow Selection

    private func selectOverflowMode(
        _ newMode:
            OverflowMode
    ) {

        cancelScheduledClose()

        withAnimation(
            .spring(
                response:
                    0.27,
                dampingFraction:
                    0.86
            )
        ) {

            overflowMode =
                newMode
        }

        switch newMode {

        case .clipboard:

            break

        case .shelf:

            handleShelfActivity()

        case .agenda:

            calendarMonitor
                .requestAccessIfNeeded()

        case .battery:

            batteryMonitor
                .refresh()
        }
    }

    // MARK: - Hover

    private func handleHover(
        _ hovering:
            Bool
    ) {

        isHovering =
            hovering

        if hovering {

            cancelScheduledClose()

            openNotch()

            return
        }

        if isClipboardPinned {

            return
        }

        if isShelfActive {

            scheduleClose(
                after:
                    shelfCloseDelay
            )

            return
        }

        scheduleClose(
            after:
                normalCloseDelay
        )
    }

    // MARK: - Shelf

    private func handleShelfActivity() {

        guard
            isShelfActive
        else {

            return
        }

        cancelScheduledClose()

        openNotch()

        if !isHovering {

            scheduleClose(
                after:
                    shelfCloseDelay
            )
        }
    }

    // MARK: - Seek

    private func handleSeekInteraction(
        _ editing:
            Bool
    ) {

        isSeeking =
            editing

        if editing {

            cancelScheduledClose()

            openNotch()

        } else if !isHovering {

            scheduleClose(
                after:
                    normalCloseDelay
            )
        }
    }

    // MARK: - Hardware

    private func handleHardwareSliderInteraction(
        _ editing:
            Bool
    ) {

        isHardwareInteracting =
            editing

        if editing {

            cancelScheduledClose()

            openNotch()

        } else if !isHovering {

            scheduleClose(
                after:
                    normalCloseDelay
            )
        }
    }

    private func handleHardwareHUDChange() {

        guard
            !isClipboardPinned
        else {

            return
        }

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
                == token,

                !isClipboardPinned
            else {

                return
            }

            hardwareHUD
                .clear()

            switchMode(
                to:
                    .media
            )

            if !isHovering {

                closeNotch()
            }
        }
    }

    // MARK: - Timer

    private func handleTimerFinished() {

        guard
            timerController.isFinished,
            !isClipboardPinned
        else {

            return
        }

        switchMode(
            to:
                .timer
        )

        openNotch()
    }

    // MARK: - Media Reveal

    private func handleMediaStateChange(
        from oldState:
            MediaState,

        to newState:
            MediaState
    ) {

        guard
            !isClipboardPinned,
            hasValidMedia
        else {

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
            trackChanged
            &&
            settings.revealOnTrackChange {

            revealTemporarily()

        } else if
            playbackStarted
            &&
            settings.revealOnPlaybackStart {

            revealTemporarily()
        }
    }

    private func revealTemporarily() {

        guard
            !isClipboardPinned
        else {

            return
        }

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

            if !isHovering {

                closeNotch()
            }
        }
    }

    // MARK: - Scheduled Close

    private func scheduleClose(
        after delay:
            TimeInterval
    ) {

        guard
            !isClipboardPinned
        else {

            return
        }

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

            showContent =
                true
        }
    }

    // MARK: - Close

    private func closeNotch() {

        guard
            !isClipboardPinned,
            !isHovering,
            !isSeeking,
            !isHardwareInteracting
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

            showContent =
                false

            expanded =
                false
        }
    }
}
