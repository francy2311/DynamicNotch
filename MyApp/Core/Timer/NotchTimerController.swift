import Foundation
import Combine
import AppKit

@MainActor
final class NotchTimerController: ObservableObject {

    @Published
    private(set) var remainingSeconds:
        TimeInterval = 0

    @Published
    private(set) var totalSeconds:
        TimeInterval = 0

    @Published
    private(set) var isRunning =
        false

    @Published
    private(set) var isFinished =
        false

    private var timer:
        Timer?

    private var targetDate:
        Date?

    // MARK: - Computed

    var progress: Double {

        guard totalSeconds > 0 else {
            return 0
        }

        return min(
            max(
                remainingSeconds / totalSeconds,
                0
            ),
            1
        )
    }

    var formattedRemainingTime:
        String {

        let seconds =
            max(
                Int(
                    remainingSeconds.rounded(.up)
                ),
                0
            )

        let hours =
            seconds / 3600

        let minutes =
            (seconds % 3600) / 60

        let remaining =
            seconds % 60

        if hours > 0 {

            return String(
                format:
                    "%d:%02d:%02d",
                hours,
                minutes,
                remaining
            )
        }

        return String(
            format:
                "%02d:%02d",
            minutes,
            remaining
        )
    }

    // MARK: - Start

    func start(
        minutes: Int
    ) {

        let safeMinutes =
            min(
                max(
                    minutes,
                    1
                ),
                120
            )

        stopInternalTimer()

        totalSeconds =
            TimeInterval(
                safeMinutes * 60
            )

        remainingSeconds =
            totalSeconds

        isFinished =
            false

        isRunning =
            true

        targetDate =
            Date()
                .addingTimeInterval(
                    totalSeconds
                )

        startInternalTimer()
    }

    // MARK: - Pause

    func pause() {

        guard isRunning else {
            return
        }

        updateRemainingTime()

        isRunning =
            false

        targetDate =
            nil

        stopInternalTimer()
    }

    // MARK: - Resume

    func resume() {

        guard
            !isRunning,
            !isFinished,
            remainingSeconds > 0
        else {
            return
        }

        isRunning =
            true

        targetDate =
            Date()
                .addingTimeInterval(
                    remainingSeconds
                )

        startInternalTimer()
    }

    // MARK: - Reset

    func reset() {

        stopInternalTimer()

        targetDate =
            nil

        totalSeconds =
            0

        remainingSeconds =
            0

        isRunning =
            false

        isFinished =
            false
    }

    // MARK: - Internal Timer

    private func startInternalTimer() {

        stopInternalTimer()

        let timer =
            Timer.scheduledTimer(
                withTimeInterval:
                    0.20,
                repeats:
                    true
            ) { [weak self] _ in

                Task { @MainActor in

                    self?
                        .updateRemainingTime()
                }
            }

        RunLoop.main.add(
            timer,
            forMode:
                .common
        )

        self.timer =
            timer
    }

    private func stopInternalTimer() {

        timer?
            .invalidate()

        timer =
            nil
    }

    private func updateRemainingTime() {

        guard
            isRunning,
            let targetDate
        else {
            return
        }

        let remaining =
            targetDate
                .timeIntervalSinceNow

        if remaining <= 0 {

            finishTimer()

            return
        }

        remainingSeconds =
            remaining
    }

    // MARK: - Finish

    private func finishTimer() {

        stopInternalTimer()

        targetDate =
            nil

        remainingSeconds =
            0

        isRunning =
            false

        isFinished =
            true

        NSSound.beep()
    }

    // MARK: - Finished State

    func clearFinishedState() {

        isFinished =
            false
    }
}
