import SwiftUI

@MainActor
struct BatteryView: View {

    // MARK: - Monitor

    @ObservedObject
    var batteryMonitor:
        BatteryMonitor

    // MARK: - Body

    var body: some View {

        VStack(
            spacing:
                12
        ) {

            if batteryMonitor.isAvailable {

                batteryInformation

                batteryProgress

            } else {

                unavailableState
            }
        }
        .foregroundStyle(
            .white
        )
        .padding(
            .horizontal,
            20
        )
        .padding(
            .bottom,
            12
        )
        .onAppear {

            batteryMonitor
                .refresh()
        }
    }

    // MARK: - Information

    private var batteryInformation:
        some View {

        HStack(
            spacing:
                14
        ) {

            batteryIcon

            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    "\(batteryMonitor.percentage)%"
                )
                .font(
                    .system(
                        size:
                            22,
                        weight:
                            .semibold,
                        design:
                            .rounded
                    )
                )
                .monospacedDigit()

                Text(
                    batteryMonitor.statusText
                )
                .font(
                    .system(
                        size:
                            10,
                        weight:
                            .medium
                    )
                )
                .foregroundStyle(
                    .secondary
                )

                if let remainingTime =
                    batteryMonitor.remainingTimeText {

                    Text(
                        remainingTime
                    )
                    .font(
                        .system(
                            size:
                                9
                        )
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Spacer()
        }
    }

    // MARK: - Icon

    private var batteryIcon:
        some View {

        ZStack {

            RoundedRectangle(
                cornerRadius:
                    13,
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
                    batteryMonitor.systemImage
            )
            .font(
                .system(
                    size:
                        22,
                    weight:
                        .medium
                )
            )
        }
        .frame(
            width:
                50,
            height:
                50
        )
    }

    // MARK: - Progress

    private var batteryProgress:
        some View {

        ProgressView(
            value:
                Double(
                    batteryMonitor.percentage
                ),
            total:
                100
        )
        .progressViewStyle(
            .linear
        )
        .tint(
            .white
        )
    }

    // MARK: - Unavailable

    private var unavailableState:
        some View {

        VStack(
            spacing:
                8
        ) {

            Image(
                systemName:
                    "battery.0"
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
                "Batteria non disponibile"
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
        }
        .frame(
            maxWidth:
                .infinity
        )
    }
}
