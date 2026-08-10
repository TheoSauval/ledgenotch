import EventKit
import SwiftUI

/// Les événements du jour, lus dans le calendrier du système.
@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var events: [EKEvent] = []
    @Published private(set) var status: EKAuthorizationStatus =
        EKEventStore.authorizationStatus(for: .event)

    private let store = EKEventStore()

    var isAuthorised: Bool { status == .fullAccess }

    /// L'autorisation n'est jamais demandée d'office : une alerte système qui
    /// surgit parce qu'on a effleuré l'encoche serait déplacée. C'est le bouton
    /// de la colonne qui la déclenche.
    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.status = EKEventStore.authorizationStatus(for: .event)
                    self.refresh()
                }
            }
        }
    }

    func refresh() {
        status = EKEventStore.authorizationStatus(for: .event)
        guard isAuthorised else {
            events = []
            return
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

        let predicate = store.predicateForEvents(
            withStart: start,
            end: end,
            calendars: nil
        )
        events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
    }

    /// Le prochain rendez-vous, ou le premier de la journée s'ils sont tous passés.
    var next: EKEvent? {
        let now = Date()
        return events.first { ($0.endDate ?? now) > now } ?? events.first
    }
}
