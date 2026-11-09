import SwiftUI

@MainActor
struct TimerView: View {

    // MARK: - Controller

    @ObservedObject
    var timerController: NotchTimerController

    // MARK: - State

    @State
    private var selectedTimerMinutes = 5

    @State
    private var isCustomTimer = false

    @State
    private var customTimerMinutes = 30

    // MARK: - Limits

    private let minimumCustomMinutes = 1
    private let maximumCustomMinutes = (23 * 60) + 59

    // MARK: - Body

    var body: some View {

        VStack(
            spacing: 10
        ) {

            if timerController.totalSeconds > 0 {

                activeTimerContent

            } else {

                timerSetupContent
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Timer Setup

    private var timerSetupContent: some View {

        VStack(
            spacing: 11
        ) {

            HStack(
                spacing: 12
            ) {

                ZStack {

                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .fill(
                        Color.white
                            .opacity(0.09)
                    )

                    Image(
                        systemName: "timer"
                    )
                    .font(
                        .system(
                            size: 17,
                            weight: .semibold
                        )
                    )
                }
                .frame(
                    width: 44,
                    height: 44
                )

                VStack(
                    alignment: .leading,
                    spacing: 1
                ) {

                    Text("Timer")
                        .font(
                            .system(
                                size: 11,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(.secondary)

                    Text(timerSetupTimeText)
                        .font(
                            .system(
                                size: 23,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .monospacedDigit()
                }

                Spacer()

                Button {

                    startSelectedTimer()

                } label: {

                    HStack(
                        spacing: 5
                    ) {

                        Image(
                            systemName: "play.fill"
                        )
                        .font(
                            .system(
                                size: 8
                            )
                        )

                        Text("Avvia")
                    }
                    .font(
                        .system(
                            size: 10,
                            weight: .semibold
                        )
                    )
                    .padding(
                        .horizontal,
                        13
                    )
                    .frame(
                        height: 28
                    )
                    .background(
                        Color.white
                            .opacity(0.15)
                    )
                    .clipShape(
                        Capsule()
                    )
                }
                .buttonStyle(.plain)
            }

            if isCustomTimer {

                customTimerSelector

            } else {

                timerPresetSelector
            }
        }
    }

    // MARK: - Setup Time

    private var timerSetupTimeText: String {

        let totalMinutes =
            isCustomTimer
            ? customTimerMinutes
            : selectedTimerMinutes

        let hours =
            totalMinutes / 60

        let minutes =
            totalMinutes % 60

        if hours > 0 {

            return String(
                format: "%d:%02d:00",
                hours,
                minutes
            )
        }

        return String(
            format: "%02d:00",
            totalMinutes
        )
    }

    // MARK: - Start

    private func startSelectedTimer() {

        let minutes =
            isCustomTimer
            ? customTimerMinutes
            : selectedTimerMinutes

        timerController.start(
            minutes: minutes
        )
    }

    // MARK: - Preset Selector

    private var timerPresetSelector: some View {

        HStack(
            spacing: 6
        ) {

            timerPresetButton(
                minutes: 5
            )

            timerPresetButton(
                minutes: 10
            )

            timerPresetButton(
                minutes: 15
            )

            timerPresetButton(
                minutes: 25
            )

            Button {

                withAnimation(
                    .easeOut(
                        duration: 0.15
                    )
                ) {

                    isCustomTimer = true
                }

            } label: {

                Image(
                    systemName: "slider.horizontal.3"
                )
                .font(
                    .system(
                        size: 10,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 32,
                    height: 27
                )
                .contentShape(
                    Rectangle()
                )
                .background(
                    Color.white
                        .opacity(0.04)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
            .help("Tempo personalizzato")
        }
    }

    private func timerPresetButton(
        minutes: Int
    ) -> some View {

        let selected =
            selectedTimerMinutes == minutes

        return Button {

            selectedTimerMinutes =
                minutes

        } label: {

            Text(
                "\(minutes) min"
            )
            .font(
                .system(
                    size: 9,
                    weight:
                        selected
                        ? .semibold
                        : .medium
                )
            )
            .foregroundStyle(
                selected
                ? .white
                : .secondary
            )
            .frame(
                maxWidth: .infinity
            )
            .frame(
                height: 27
            )
            .contentShape(
                Rectangle()
            )
            .background(
                Color.white
                    .opacity(
                        selected
                        ? 0.14
                        : 0.04
                    )
            )
            .overlay {

                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
                .stroke(
                    Color.white
                        .opacity(
                            selected
                            ? 0.13
                            : 0
                        ),
                    lineWidth: 1
                )
            }
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Custom Timer Selector

    private var customTimerSelector: some View {

        HStack(
            spacing: 6
        ) {

            Button {

                guard
                    customTimerMinutes >
                        minimumCustomMinutes
                else {
                    return
                }

                customTimerMinutes -= 1

            } label: {

                Image(
                    systemName: "minus"
                )
                .font(
                    .system(
                        size: 9,
                        weight: .bold
                    )
                )
                .frame(
                    width: 32,
                    height: 27
                )
                .contentShape(
                    Rectangle()
                )
                .background(
                    Color.white
                        .opacity(0.08)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)

            Text(
                customTimerDisplayText
            )
            .font(
                .system(
                    size: 10,
                    weight: .semibold,
                    design: .rounded
                )
            )
            .monospacedDigit()
            .frame(
                maxWidth: .infinity
            )
            .frame(
                height: 27
            )
            .background(
                Color.white
                    .opacity(0.06)
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
            )

            Button {

                guard
                    customTimerMinutes <
                        maximumCustomMinutes
                else {
                    return
                }

                customTimerMinutes += 1

            } label: {

                Image(
                    systemName: "plus"
                )
                .font(
                    .system(
                        size: 9,
                        weight: .bold
                    )
                )
                .frame(
                    width: 32,
                    height: 27
                )
                .contentShape(
                    Rectangle()
                )
                .background(
                    Color.white
                        .opacity(0.08)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)

            Button {

                withAnimation(
                    .easeOut(
                        duration: 0.15
                    )
                ) {

                    isCustomTimer = false
                }

            } label: {

                Image(
                    systemName: "xmark"
                )
                .font(
                    .system(
                        size: 9,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .secondary
                )
                .frame(
                    width: 32,
                    height: 27
                )
                .contentShape(
                    Rectangle()
                )
                .background(
                    Color.white
                        .opacity(0.04)
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 8,
                        style: .continuous
                    )
                )
            }
            .buttonStyle(.plain)
            .help("Torna ai preset")
        }
    }

    private var customTimerDisplayText: String {

        let hours =
            customTimerMinutes / 60

        let minutes =
            customTimerMinutes % 60

        if hours == 0 {
            return "\(minutes) min"
        }

        if minutes == 0 {

            return hours == 1
            ? "1 h"
            : "\(hours) h"
        }

        return "\(hours) h \(minutes) min"
    }

    // MARK: - Active Timer

    private var activeTimerContent: some View {

        VStack(
            spacing: 10
        ) {

            HStack(
                spacing: 12
            ) {

                ZStack {

                    RoundedRectangle(
                        cornerRadius: 12,
                        style: .continuous
                    )
                    .fill(
                        Color.white
                            .opacity(
                                timerController.isFinished
                                ? 0.15
                                : 0.09
                            )
                    )

                    Image(
                        systemName:
                            timerController.isFinished
                            ? "bell.fill"
                            : timerController.isRunning
                            ? "timer"
                            : "pause.fill"
                    )
                    .font(
                        .system(
                            size: 17,
                            weight: .semibold
                        )
                    )
                }
                .frame(
                    width: 44,
                    height: 44
                )

                VStack(
                    alignment: .leading,
                    spacing: 1
                ) {

                    Text(
                        timerController.isFinished
                        ? "Timer terminato"
                        : timerController.isRunning
                        ? "Timer in corso"
                        : "Timer in pausa"
                    )
                    .font(
                        .system(
                            size: 10,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Text(
                        timerController
                            .formattedRemainingTime
                    )
                    .font(
                        .system(
                            size: 23,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .monospacedDigit()
                }

                Spacer()

                if timerController.isFinished {

                    Button {

                        timerController
                            .reset()

                    } label: {

                        Image(
                            systemName:
                                "arrow.counterclockwise"
                        )
                        .font(
                            .system(
                                size: 11,
                                weight: .semibold
                            )
                        )
                        .frame(
                            width: 30,
                            height: 30
                        )
                        .background(
                            Color.white
                                .opacity(0.10)
                        )
                        .clipShape(
                            Circle()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if !timerController.isFinished {

                VStack(
                    spacing: 8
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

                    HStack(
                        spacing: 8
                    ) {

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
                            .font(
                                .system(
                                    size: 9,
                                    weight: .semibold
                                )
                            )
                            .frame(
                                maxWidth: .infinity
                            )
                            .frame(
                                height: 27
                            )
                            .background(
                                Color.white
                                    .opacity(0.12)
                            )
                            .clipShape(
                                Capsule()
                            )
                        }
                        .buttonStyle(.plain)

                        Button {

                            timerController
                                .reset()

                        } label: {

                            Label(
                                "Annulla",
                                systemImage:
                                    "xmark"
                            )
                            .font(
                                .system(
                                    size: 9,
                                    weight: .semibold
                                )
                            )
                            .foregroundStyle(
                                .secondary
                            )
                            .frame(
                                maxWidth: .infinity
                            )
                            .frame(
                                height: 27
                            )
                            .background(
                                Color.white
                                    .opacity(0.05)
                            )
                            .clipShape(
                                Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

            } else {

                HStack {

                    Text(
                        "Tempo scaduto"
                    )
                    .font(
                        .system(
                            size: 10,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )

                    Spacer()

                    Button {

                        timerController
                            .reset()

                    } label: {

                        Text(
                            "Nuovo timer"
                        )
                        .font(
                            .system(
                                size: 10,
                                weight: .semibold
                            )
                        )
                        .padding(
                            .horizontal,
                            12
                        )
                        .frame(
                            height: 27
                        )
                        .background(
                            Color.white
                                .opacity(0.13)
                        )
                        .clipShape(
                            Capsule()
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
