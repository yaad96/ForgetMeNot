import EventKit
import Combine

class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var events: [EKEvent] = []
    @Published var permissionDenied = false
    @Published var loading = false

    func requestAndFetchEvents() {
        loading = true
        eventStore.requestAccess(to: .event) { [weak self] granted, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.permissionDenied = !granted
                self.loading = false
            }
            guard granted else { return }
            let now = Date()
            let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: now)!
            let predicate = self.eventStore.predicateForEvents(withStart: now, end: oneMonthLater, calendars: nil)
            let events = self.eventStore.events(matching: predicate)
            DispatchQueue.main.async {
                self.events = events
            }
        }
    }
}
