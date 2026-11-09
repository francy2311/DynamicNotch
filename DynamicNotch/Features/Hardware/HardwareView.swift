import SwiftUI

@MainActor
struct HardwareView: View {

    // MARK: - Monitor

    @ObservedObject
    var hardwareHUD:
        HardwareHUDMonitor

    // MARK: - Kind

    let kind:
        HardwareHUDMonitor.Kind

    // MARK: - Interaction

    let onInteractionChanged:
        (Bool) -> Void

    // MARK: - Body

    var body: some View {

        VStack(
            spacing:
                11
        ) {

            HStack {

                hardwareButton

                VStack(
                    alignment:
                        .leading
                ) {

                    Text(
                        title
                    )
                    .fontWeight(
                        .semibold
                    )

                    Text(
                        percentageText
                    )
                    .foregroundStyle(
                        .secondary
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
                        set: {

                            hardwareHUD
                                .setCurrentValue(
                                    $0
                                )
                        }
                    ),
                in:
                    0...1,
                onEditingChanged: {
                    editing in

                    onInteractionChanged(
                        editing
                    )
                }
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

    // MARK: - Values

    private var value:
        Double {

        hardwareHUD
            .presentation?
            .value
        ?? 0
    }

    private var title:
        String {

        switch kind {

        case .volume:
            return "Volume"

        case .brightness:
            return "Luminosità"
        }
    }

    private var percentageText:
        String {

        "\(Int((value * 100).rounded()))%"
    }

    private var icon:
        String {

        hardwareHUD
            .presentation?
            .systemImage
        ??
        (
            kind == .volume
            ? "speaker.wave.2.fill"
            : "sun.max.fill"
        )
    }

    // MARK: - Hardware Button

    private var hardwareButton:
        some View {

        Button {

            if kind == .volume {

                hardwareHUD
                    .toggleMute()
            }

        } label: {

            Image(
                systemName:
                    icon
            )
            .frame(
                width:
                    44,
                height:
                    44
            )
            .background(
                Color.white
                    .opacity(
                        0.10
                    )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius:
                        12
                )
            )
        }
        .buttonStyle(
            .plain
        )
    }
}
