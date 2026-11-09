import Foundation
import EventKit
import Combine

@MainActor
final class CalendarMonitor: ObservableObject {

    // MARK: - Access State

    enum AccessState: Equatable {
        case notDetermined
        case denied
        case restricted
        case writeOnly
        case fullAccess
    }

    // MARK: - Calendar Option

    struct CalendarOption: Identifiable, Equatable {

        let id: String
        let title: String
        let sourceTitle: String

        var displayTitle: String {

            if sourceTitle.isEmpty {
                return title
            }

            return "\(title) · \(sourceTitle)"
        }
    }

    // MARK: - Event

    struct CalendarEvent: Identifiable, Equatable {

        let id: String
        let title: String

        let startDate: Date
        let endDate: Date

        let location: String
        let calendarTitle: String

        let joinURL: URL?

        var isOngoing: Bool {

            let now = Date()

            return startDate <= now
                && endDate > now
        }
    }

    // MARK: - Published

    @Published
    private(set) var accessState:
        AccessState = .notDetermined

    @Published
    private(set) var nextEvent:
        CalendarEvent?

    @Published
    private(set) var availableCalendars:
        [CalendarOption] = []

    @Published
    private(set) var selectedCalendarID:
        String?

    @Published
    private(set) var isLoading =
        false

    @Published
    private(set) var errorMessage:
        String?

    // MARK: - Persistence

    private static let selectedCalendarKey =
        "dynamicNotch.selectedCalendarID"

    // MARK: - Event Store

    private let eventStore =
        EKEventStore()

    // MARK: - Combine

    private var cancellables =
        Set<AnyCancellable>()

    // MARK: - Init

    init() {

        selectedCalendarID =
            UserDefaults.standard.string(
                forKey:
                    Self.selectedCalendarKey
            )

        updateAuthorizationState()

        observeCalendarChanges()

        startRefreshTimer()

        if accessState == .fullAccess {

            refreshCalendars()

            refresh()
        }
    }

    // MARK: - Selected Calendar

    var selectedCalendarTitle:
        String {

        guard
            let selectedCalendarID
        else {

            return "Tutti"
        }

        guard
            let calendar =
                availableCalendars.first(
                    where: {
                        $0.id == selectedCalendarID
                    }
                )
        else {

            return "Tutti"
        }

        return calendar.title
    }

    func selectCalendar(
        _ calendarID:
            String?
    ) {

        selectedCalendarID =
            calendarID

        if let calendarID {

            UserDefaults.standard.set(
                calendarID,
                forKey:
                    Self.selectedCalendarKey
            )

        } else {

            UserDefaults.standard.removeObject(
                forKey:
                    Self.selectedCalendarKey
            )
        }

        refresh()
    }

    // MARK: - Permissions

    func requestAccessIfNeeded() {

        updateAuthorizationState()

        switch accessState {

        case .fullAccess:

            refreshCalendars()

            refresh()

        case .notDetermined:

            requestFullAccess()

        case .denied,
             .restricted,
             .writeOnly:

            break
        }
    }

    private func requestFullAccess() {

        guard !isLoading else {
            return
        }

        isLoading =
            true

        errorMessage =
            nil

        Task {

            do {

                let granted =
                    try await eventStore
                        .requestFullAccessToEvents()

                isLoading =
                    false

                updateAuthorizationState()

                if granted {

                    refreshCalendars()

                    refresh()
                }

            } catch {

                isLoading =
                    false

                errorMessage =
                    error.localizedDescription

                updateAuthorizationState()
            }
        }
    }

    private func updateAuthorizationState() {

        let status =
            EKEventStore.authorizationStatus(
                for:
                    .event
            )

        switch status {

        case .notDetermined:

            accessState =
                .notDetermined

        case .restricted:

            accessState =
                .restricted

        case .denied:

            accessState =
                .denied

        case .writeOnly:

            accessState =
                .writeOnly

        case .fullAccess:

            accessState =
                .fullAccess

        case .authorized:

            /*
             Compatibilità con versioni
             precedenti di macOS.
             */

            accessState =
                .fullAccess

        @unknown default:

            accessState =
                .denied
        }
    }

    // MARK: - Calendars

    func refreshCalendars() {

        updateAuthorizationState()

        guard
            accessState == .fullAccess
        else {

            availableCalendars =
                []

            return
        }

        let calendars =
            eventStore
                .calendars(
                    for:
                        .event
                )
                .sorted {

                    let left =
                        $0.title.localizedLowercase

                    let right =
                        $1.title.localizedLowercase

                    if left == right {

                        return
                            $0.source.title.localizedLowercase
                            <
                            $1.source.title.localizedLowercase
                    }

                    return left < right
                }

        availableCalendars =
            calendars.map {

                CalendarOption(
                    id:
                        $0.calendarIdentifier,

                    title:
                        $0.title,

                    sourceTitle:
                        $0.source.title
                )
            }

        /*
         Se il calendario salvato non esiste
         più, torniamo automaticamente a
         "Tutti".
         */

        guard
            let selectedCalendarID
        else {

            return
        }

        let exists =
            calendars.contains {

                $0.calendarIdentifier
                    == selectedCalendarID
            }

        if !exists {

            self.selectedCalendarID =
                nil

            UserDefaults.standard.removeObject(
                forKey:
                    Self.selectedCalendarKey
            )
        }
    }

    // MARK: - Refresh

    func refresh() {

        updateAuthorizationState()

        guard
            accessState == .fullAccess
        else {

            nextEvent =
                nil

            return
        }

        refreshCalendars()

        let now =
            Date()

        /*
         Partiamo alcune ore prima di "adesso"
         perché vogliamo trovare anche un
         evento già iniziato ma ancora in corso.
         */

        guard
            let startDate =
                Calendar.current.date(
                    byAdding:
                        .hour,
                    value:
                        -12,
                    to:
                        now
                ),

            let endDate =
                Calendar.current.date(
                    byAdding:
                        .hour,
                    value:
                        24,
                    to:
                        now
                )
        else {

            return
        }

        // MARK: Calendar Filter

        let calendars:
            [EKCalendar]?

        if
            let selectedCalendarID,

            let selectedCalendar =
                eventStore
                    .calendars(
                        for:
                            .event
                    )
                    .first(
                        where: {

                            $0.calendarIdentifier
                                == selectedCalendarID
                        }
                    )
        {

            calendars =
                [selectedCalendar]

        } else {

            /*
             nil significa:
             tutti i calendari.
             */

            calendars =
                nil
        }

        let predicate =
            eventStore
                .predicateForEvents(
                    withStart:
                        startDate,

                    end:
                        endDate,

                    calendars:
                        calendars
                )

        let events =
            eventStore
                .events(
                    matching:
                        predicate
                )

        let validEvents =
            events
                .filter {

                    $0.status != .canceled
                }
                .filter {

                    $0.endDate > now
                }
                .filter {

                    /*
                     Continuiamo a ignorare
                     gli eventi "tutto il giorno"
                     per mantenere Agenda utile
                     soprattutto per meeting,
                     lezioni e appuntamenti.
                     */

                    !$0.isAllDay
                }

        // MARK: Ongoing Event

        /*
         Prima cerchiamo un evento
         attualmente in corso.
         */

        let ongoingEvents =
            validEvents
                .filter {

                    $0.startDate <= now
                    &&
                    $0.endDate > now
                }
                .sorted {

                    $0.startDate < $1.startDate
                }

        if
            let currentEvent =
                ongoingEvents.first
        {

            nextEvent =
                makeCalendarEvent(
                    from:
                        currentEvent
                )

            return
        }

        // MARK: Next Event

        /*
         Se nulla è in corso,
         mostriamo il prossimo evento.
         */

        let futureEvents =
            validEvents
                .filter {

                    $0.startDate > now
                }
                .sorted {

                    $0.startDate < $1.startDate
                }

        guard
            let event =
                futureEvents.first
        else {

            nextEvent =
                nil

            return
        }

        nextEvent =
            makeCalendarEvent(
                from:
                    event
            )
    }

    // MARK: - Event Mapping

    private func makeCalendarEvent(
        from event:
            EKEvent
    ) -> CalendarEvent {

        CalendarEvent(
            id:
                event.eventIdentifier
                ?? UUID().uuidString,

            title:
                normalizedTitle(
                    event.title
                ),

            startDate:
                event.startDate,

            endDate:
                event.endDate,

            location:
                event.location
                ?? "",

            calendarTitle:
                event.calendar.title,

            joinURL:
                meetingURL(
                    from:
                        event
                )
        )
    }

    private func normalizedTitle(
        _ title:
            String?
    ) -> String {

        let trimmed =
            title?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        return trimmed.isEmpty
            ? "Evento"
            : trimmed
    }

    // MARK: - Meeting URL

    private func meetingURL(
        from event:
            EKEvent
    ) -> URL? {

        /*
         Prima usiamo l'URL associato
         direttamente all'evento.
         */

        if
            let url =
                event.url,

            isWebURL(
                url
            )
        {

            return url
        }

        /*
         In alternativa cerchiamo link
         nelle note e nella location.
         */

        let texts:
            [String] = [

                event.location
                    ?? "",

                event.notes
                    ?? ""
            ]

        var fallbackURL:
            URL?

        for text in texts {

            let urls =
                extractURLs(
                    from:
                        text
                )

            for url in urls {

                if isMeetingURL(
                    url
                ) {

                    return url
                }

                if
                    fallbackURL == nil,
                    isWebURL(
                        url
                    )
                {

                    fallbackURL =
                        url
                }
            }
        }

        return fallbackURL
    }

    private func extractURLs(
        from text:
            String
    ) -> [URL] {

        guard
            !text.isEmpty
        else {

            return []
        }

        guard
            let detector =
                try? NSDataDetector(
                    types:
                        NSTextCheckingResult
                            .CheckingType
                            .link
                            .rawValue
                )
        else {

            return []
        }

        let range =
            NSRange(
                text.startIndex...,
                in:
                    text
            )

        return detector
            .matches(
                in:
                    text,
                options:
                    [],
                range:
                    range
            )
            .compactMap {

                $0.url
            }
    }

    private func isMeetingURL(
        _ url:
            URL
    ) -> Bool {

        let host =
            url.host?
                .lowercased()
            ?? ""

        return
            host.contains(
                "zoom.us"
            )
            ||
            host.contains(
                "meet.google.com"
            )
            ||
            host.contains(
                "teams.microsoft.com"
            )
            ||
            host.contains(
                "teams.live.com"
            )
            ||
            host.contains(
                "webex.com"
            )
    }

    private func isWebURL(
        _ url:
            URL
    ) -> Bool {

        guard
            let scheme =
                url.scheme?
                    .lowercased()
        else {

            return false
        }

        return
            scheme == "http"
            ||
            scheme == "https"
    }

    // MARK: - Calendar Updates

    private func observeCalendarChanges() {

        NotificationCenter
            .default
            .publisher(
                for:
                    .EKEventStoreChanged
            )
            .receive(
                on:
                    RunLoop.main
            )
            .sink { [weak self] _ in

                guard
                    let self
                else {

                    return
                }

                self.refreshCalendars()

                self.refresh()
            }
            .store(
                in:
                    &cancellables
            )
    }

    // MARK: - Periodic Refresh

    private func startRefreshTimer() {

        Timer
            .publish(
                every:
                    60,
                on:
                    .main,
                in:
                    .common
            )
            .autoconnect()
            .sink { [weak self] _ in

                guard
                    let self,
                    self.accessState
                        == .fullAccess
                else {

                    return
                }

                self.refresh()
            }
            .store(
                in:
                    &cancellables
            )
    }
}
