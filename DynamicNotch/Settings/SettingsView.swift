import SwiftUI

struct SettingsView: View {

    @ObservedObject
    private var settings =
        AppSettings.shared

    var body: some View {

        Form {

            // MARK: - General

            Section("Generale") {

                Toggle(
                    "Avvia Dynamic Notch al login",
                    isOn:
                        $settings.launchAtLogin
                )
            }

            // MARK: - Media

            Section("Media") {

                Toggle(
                    "Apri al cambio traccia",
                    isOn:
                        $settings.revealOnTrackChange
                )

                Toggle(
                    "Apri quando parte la riproduzione",
                    isOn:
                        $settings.revealOnPlaybackStart
                )

                VStack(
                    alignment:
                        .leading,
                    spacing:
                        10
                ) {

                    HStack {

                        Text(
                            "Durata apertura automatica"
                        )

                        Spacer()

                        Text(
                            String(
                                format:
                                    "%.1f s",
                                settings.mediaRevealDuration
                            )
                        )
                        .foregroundStyle(
                            .secondary
                        )
                    }

                    Slider(
                        value:
                            $settings.mediaRevealDuration,
                        in:
                            1.0...5.0,
                        step:
                            0.5
                    )
                }
            }

            // MARK: - Display

            Section("Display") {

                Picker(
                    "Mostra Dynamic Notch su",
                    selection:
                        $settings.displayMode
                ) {

                    ForEach(
                        AppSettings.DisplayMode.allCases
                    ) { mode in

                        Text(
                            mode.title
                        )
                        .tag(
                            mode
                        )
                    }
                }
                .pickerStyle(
                    .radioGroup
                )

                Text(
                    "In modalità Automatica, Dynamic Notch preferisce il display integrato del MacBook. Se non è disponibile, utilizza il display principale."
                )
                .font(
                    .caption
                )
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .formStyle(
            .grouped
        )
        .padding()
        .frame(
            width:
                500,
            height:
                520
        )
    }
}
