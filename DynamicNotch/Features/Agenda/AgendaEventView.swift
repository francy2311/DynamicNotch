import SwiftUI
import AppKit

@MainActor
struct AgendaEventView: View {

    // MARK: - Event

    let event:
        CalendarMonitor.CalendarEvent

    // MARK: - Body

    var body: some View {

        TimelineView(
            .periodic(
                from:
                    .now,
                by:
                    1
            )
        ) { context in

            VStack(
                spacing:
                    11
            ) {

                eventInformation(
                    now:
                        context.date
                )

                actions
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
        }
    }

    // MARK: - Information

    private func eventInformation(
        now:
            Date
    ) -> some View {

        HStack(
            spacing:
                12
        ) {

            eventIcon

            VStack(
                alignment:
                    .leading,
                spacing:
                    3
            ) {

                Text(
                    event.title
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

                HStack(
                    spacing:
                        5
                ) {

                    Text(
                        formatEventTime(
                            event.startDate
                        )
                    )

                    Text(
                        "·"
                    )

                    Text(
                        relativeEventText(
                            now:
                                now
                        )
                    )
                }
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
                .monospacedDigit()

                calendarAndLocation
            }

            Spacer()
        }
    }

    // MARK: - Icon

    private var eventIcon:
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
                        0.09
                    )
            )

            Image(
                systemName:
                    event.isOngoing
                    ? "video.fill"
                    : "calendar"
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

    // MARK: - Calendar / Location

    private var calendarAndLocation:
        some View {

        HStack(
            spacing:
                5
        ) {

            Text(
                event.calendarTitle
            )

            if !event.location
                .isEmpty {

                Text(
                    "·"
                )

                Text(
                    event.location
                )
                .lineLimit(
                    1
                )
            }
        }
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

    // MARK: - Actions

    private var actions:
        some View {

        HStack(
            spacing:
                8
        ) {

            if let joinURL =
                event.joinURL {

                Button {

                    NSWorkspace.shared
                        .open(
                            joinURL
                        )

                } label: {

                    Label(
                        "Join",
                        systemImage:
                            "video.fill"
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
                            28
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
                .buttonStyle(
                    .plain
                )
            }

            Button {

                openCalendarApp()

            } label: {

                Label(
                    "Calendario",
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
                .frame(
                    maxWidth:
                        .infinity
                )
                .frame(
                    height:
                        28
                )
                .background(
                    Color.white
                        .opacity(
                            0.07
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
    }

    // MARK: - Relative Time

    private func relativeEventText(
        now:
            Date
    ) -> String {

        if event.startDate <= now,
           event.endDate > now {

            let remaining =
                event.endDate
                    .timeIntervalSince(
                        now
                    )

            return "in corso · \(compactDuration(remaining))"
        }

        let remaining =
            event.startDate
                .timeIntervalSince(
                    now
                )

        if remaining <= 0 {

            return "ora"
        }

        return "tra \(compactDuration(remaining))"
    }

    // MARK: - Duration

    private func compactDuration(
        _ interval:
            TimeInterval
    ) -> String {

        let totalMinutes =
            max(
                Int(
                    interval / 60
                ),
                0
            )

        if totalMinutes < 1 {

            return "<1 min"
        }

        if totalMinutes < 60 {

            return "\(totalMinutes) min"
        }

        let hours =
            totalMinutes / 60

        let minutes =
            totalMinutes % 60

        if minutes == 0 {

            return "\(hours) h"
        }

        return "\(hours) h \(minutes) min"
    }

    // MARK: - Time Formatter

    private func formatEventTime(
        _ date:
            Date
    ) -> String {

        date.formatted(
            date:
                .omitted,
            time:
                .shortened
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
}
