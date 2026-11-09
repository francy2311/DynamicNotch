import Foundation
import Combine
import IOKit.ps

@MainActor
final class BatteryMonitor: ObservableObject {

    // MARK: - Published State

    @Published
    private(set) var percentage: Int = 0

    @Published
    private(set) var isCharging: Bool = false

    @Published
    private(set) var isPluggedIn: Bool = false

    @Published
    private(set) var timeToEmptyMinutes: Int?

    @Published
    private(set) var timeToFullMinutes: Int?

    @Published
    private(set) var isAvailable: Bool = false

    // MARK: - Timer

    private var timer: Timer?

    // MARK: - Init

    init() {

        refresh()

        startMonitoring()
    }

    deinit {

        timer?
            .invalidate()
    }

    // MARK: - Monitoring

    private func startMonitoring() {

        let timer =
            Timer.scheduledTimer(
                withTimeInterval:
                    15,
                repeats:
                    true
            ) { [weak self] _ in

                Task { @MainActor in

                    self?
                        .refresh()
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

    // MARK: - Refresh

    func refresh() {

        let powerSourcesInfo =
            IOPSCopyPowerSourcesInfo()
                .takeRetainedValue()

        let powerSources =
            IOPSCopyPowerSourcesList(
                powerSourcesInfo
            )
            .takeRetainedValue() as Array

        for source in powerSources {

            guard
                let description =
                    IOPSGetPowerSourceDescription(
                        powerSourcesInfo,
                        source
                    )?
                    .takeUnretainedValue()
                    as? [String: Any]
            else {
                continue
            }

            guard
                let type =
                    description[
                        kIOPSTypeKey
                    ] as? String,
                type ==
                    kIOPSInternalBatteryType
            else {
                continue
            }

            update(
                from:
                    description
            )

            return
        }

        reset()
    }

    // MARK: - Update

    private func update(
        from description:
            [String: Any]
    ) {

        let currentCapacity =
            description[
                kIOPSCurrentCapacityKey
            ] as? Int
            ?? 0

        let maximumCapacity =
            description[
                kIOPSMaxCapacityKey
            ] as? Int
            ?? 100

        if maximumCapacity > 0 {

            percentage =
                Int(
                    (
                        Double(
                            currentCapacity
                        )
                        /
                        Double(
                            maximumCapacity
                        )
                    )
                    * 100
                )

        } else {

            percentage =
                currentCapacity
        }

        percentage =
            min(
                max(
                    percentage,
                    0
                ),
                100
            )

        isCharging =
            description[
                kIOPSIsChargingKey
            ] as? Bool
            ?? false

        let powerState =
            description[
                kIOPSPowerSourceStateKey
            ] as? String

        isPluggedIn =
            powerState
            == kIOPSACPowerValue

        let emptyValue =
            description[
                kIOPSTimeToEmptyKey
            ] as? Int

        if let emptyValue,
           emptyValue > 0 {

            timeToEmptyMinutes =
                emptyValue

        } else {

            timeToEmptyMinutes =
                nil
        }

        let fullValue =
            description[
                kIOPSTimeToFullChargeKey
            ] as? Int

        if let fullValue,
           fullValue > 0 {

            timeToFullMinutes =
                fullValue

        } else {

            timeToFullMinutes =
                nil
        }

        isAvailable =
            true
    }

    // MARK: - Reset

    private func reset() {

        percentage =
            0

        isCharging =
            false

        isPluggedIn =
            false

        timeToEmptyMinutes =
            nil

        timeToFullMinutes =
            nil

        isAvailable =
            false
    }

    // MARK: - Display

    var systemImage:
        String {

        if isCharging {

            return "battery.100percent.bolt"
        }

        switch percentage {

        case 0..<15:

            return "battery.0percent"

        case 15..<40:

            return "battery.25percent"

        case 40..<65:

            return "battery.50percent"

        case 65..<90:

            return "battery.75percent"

        default:

            return "battery.100percent"
        }
    }

    var statusText:
        String {

        if isCharging {

            if percentage >= 100 {

                return "Carica completata"
            }

            return "In carica"
        }

        if isPluggedIn {

            return "Alimentatore collegato"
        }

        return "A batteria"
    }

    var remainingTimeText:
        String? {

        if isCharging {

            guard
                let minutes =
                    timeToFullMinutes
            else {
                return nil
            }

            return formatMinutes(
                minutes
            )
            + " alla carica completa"
        }

        guard
            let minutes =
                timeToEmptyMinutes
        else {
            return nil
        }

        return formatMinutes(
            minutes
        )
        + " rimanenti"
    }

    // MARK: - Formatting

    private func formatMinutes(
        _ minutes:
            Int
    ) -> String {

        let hours =
            minutes / 60

        let remainingMinutes =
            minutes % 60

        if hours == 0 {

            return "\(remainingMinutes) min"
        }

        if remainingMinutes == 0 {

            return "\(hours) h"
        }

        return "\(hours) h \(remainingMinutes) min"
    }
}
