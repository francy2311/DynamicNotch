import SwiftUI

@MainActor
struct AgendaCalendarMenu: View {

    // MARK: - Monitor

    @ObservedObject
    var calendarMonitor:
        CalendarMonitor

    // MARK: - Body

    var body: some View {

        Menu {

            allCalendarsButton

            if !calendarMonitor
                .availableCalendars
                .isEmpty {

                Divider()

                calendarButtons
            }

        } label: {

            menuLabel
        }
        .menuStyle(
            .borderlessButton
        )
        .fixedSize()
    }

    // MARK: - All Calendars

    private var allCalendarsButton:
        some View {

        Button {

            calendarMonitor
                .selectCalendar(
                    nil
                )

        } label: {

            if calendarMonitor
                .selectedCalendarID
                == nil {

                Label(
                    "Tutti i calendari",
                    systemImage:
                        "checkmark"
                )

            } else {

                Text(
                    "Tutti i calendari"
                )
            }
        }
    }

    // MARK: - Calendar Buttons

    @ViewBuilder
    private var calendarButtons:
        some View {

        ForEach(
            calendarMonitor
                .availableCalendars
        ) { calendar in

            Button {

                calendarMonitor
                    .selectCalendar(
                        calendar.id
                    )

            } label: {

                if calendarMonitor
                    .selectedCalendarID
                    == calendar.id {

                    Label(
                        calendar.displayTitle,
                        systemImage:
                            "checkmark"
                    )

                } else {

                    Text(
                        calendar.displayTitle
                    )
                }
            }
        }
    }

    // MARK: - Label

    private var menuLabel:
        some View {

        HStack(
            spacing:
                5
        ) {

            Image(
                systemName:
                    "calendar"
            )
            .font(
                .system(
                    size:
                        9,
                    weight:
                        .semibold
                )
            )

            Text(
                calendarMonitor
                    .selectedCalendarTitle
            )
            .lineLimit(
                1
            )

            Image(
                systemName:
                    "chevron.down"
            )
            .font(
                .system(
                    size:
                        7,
                    weight:
                        .bold
                )
            )
        }
        .font(
            .system(
                size:
                    9,
                weight:
                    .semibold
            )
        )
        .foregroundStyle(
            .white
        )
        .padding(
            .horizontal,
            9
        )
        .frame(
            height:
                24
        )
        .background(
            Color.white
                .opacity(
                    0.08
                )
        )
        .clipShape(
            Capsule()
        )
    }
}
