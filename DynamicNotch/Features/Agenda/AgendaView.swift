import SwiftUI
import AppKit

@MainActor
struct AgendaView: View {

    // MARK: - Monitor

    @ObservedObject
    var calendarMonitor:
        CalendarMonitor

    // MARK: - Body

    var body: some View {

        VStack(
            spacing:
                8
        ) {

            switch calendarMonitor.accessState {

            case .notDetermined:

                permissionContent

            case .denied,
                 .restricted,
                 .writeOnly:

                deniedContent

            case .fullAccess:

                agendaContent
            }
        }
        .foregroundStyle(
            .white
        )
        .onAppear {

            if calendarMonitor.accessState
                == .fullAccess {

                calendarMonitor
                    .refreshCalendars()

                calendarMonitor
                    .refresh()
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var agendaContent:
        some View {

        header

        if calendarMonitor.isLoading {

            loadingContent

        } else if let event =
            calendarMonitor.nextEvent {

            AgendaEventView(
                event:
                    event
            )

        } else {

            emptyContent
        }
    }

    // MARK: - Header

    private var header:
        some View {

        HStack(
            spacing:
                8
        ) {

            Text(
                "Agenda"
            )
            .font(
                .system(
                    size:
                        11,
                    weight:
                        .semibold
                )
            )

            Spacer()

            AgendaCalendarMenu(
                calendarMonitor:
                    calendarMonitor
            )
        }
        .padding(
            .horizontal,
            20
        )
    }

    // MARK: - Permission

    private var permissionContent:
        some View {

        VStack(
            spacing:
                10
        ) {

            Image(
                systemName:
                    "calendar.badge.clock"
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
                "Collega il calendario"
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
                "Dynamic Notch può mostrarti il prossimo evento senza inviare dati all'esterno."
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
            .multilineTextAlignment(
                .center
            )
            .frame(
                maxWidth:
                    300
            )

            Button {

                calendarMonitor
                    .requestAccessIfNeeded()

            } label: {

                Label(
                    calendarMonitor.isLoading
                    ? "Richiesta in corso…"
                    : "Consenti accesso",

                    systemImage:
                        "calendar"
                )
                .font(
                    .system(
                        size:
                            10,
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
                        27
                )
                .background(
                    Color.white
                        .opacity(
                            0.14
                        )
                )
                .clipShape(
                    Capsule()
                )
            }
            .buttonStyle(
                .plain
            )
            .disabled(
                calendarMonitor.isLoading
            )
        }
        .padding(
            .horizontal,
            20
        )
        .padding(
            .bottom,
            12
        )
    }

    // MARK: - Denied

    private var deniedContent:
        some View {

        VStack(
            spacing:
                9
        ) {

            Image(
                systemName:
                    "calendar.badge.exclamationmark"
            )
            .font(
                .system(
                    size:
                        23
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                "Accesso al calendario disattivato"
            )
            .font(
                .system(
                    size:
                        12,
                    weight:
                        .semibold
                )
            )

            Text(
                "Puoi abilitarlo da Impostazioni di Sistema → Privacy e sicurezza → Calendari."
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
            .multilineTextAlignment(
                .center
            )
            .frame(
                maxWidth:
                    300
            )

            Button {

                openCalendarPrivacySettings()

            } label: {

                Label(
                    "Apri Impostazioni",
                    systemImage:
                        "gear"
                )
                .font(
                    .system(
                        size:
                            10,
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
                        27
                )
                .background(
                    Color.white
                        .opacity(
                            0.12
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
        .padding(
            .horizontal,
            20
        )
        .padding(
            .bottom,
            12
        )
    }

    // MARK: - Loading

    private var loadingContent:
        some View {

        VStack(
            spacing:
                8
        ) {

            ProgressView()

            Text(
                "Carico il prossimo evento…"
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
        .frame(
            maxWidth:
                .infinity
        )
        .padding(
            .bottom,
            12
        )
    }

    // MARK: - Empty

    private var emptyContent:
        some View {

        VStack(
            spacing:
                8
        ) {

            Image(
                systemName:
                    "calendar.badge.checkmark"
            )
            .font(
                .system(
                    size:
                        23
                )
            )
            .foregroundStyle(
                .secondary
            )

            Text(
                "Nessun evento nelle prossime 24 ore"
            )
            .font(
                .system(
                    size:
                        12,
                    weight:
                        .semibold
                )
            )

            Button {

                openCalendarApp()

            } label: {

                Text(
                    "Apri Calendario"
                )
                .font(
                    .system(
                        size:
                            9,
                        weight:
                            .semibold
                    )
                )
            }
            .buttonStyle(
                .plain
            )
            .foregroundStyle(
                .secondary
            )
        }
        .frame(
            maxWidth:
                .infinity
        )
        .padding(
            .bottom,
            12
        )
    }

    // MARK: - Calendar App

    private func openCalendarApp() {

        guard
            let applicationURL =
                NSWorkspace
                    .shared
                    .urlForApplication(
                        withBundleIdentifier:
                            "com.apple.iCal"
                    )
        else {

            return
        }

        NSWorkspace.shared
            .open(
                applicationURL
            )
    }

    // MARK: - Privacy Settings

    private func openCalendarPrivacySettings() {

        guard
            let url =
                URL(
                    string:
                        "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
                )
        else {

            return
        }

        NSWorkspace.shared
            .open(
                url
            )
    }
}
