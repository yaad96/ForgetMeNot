import Foundation
import UserNotifications

struct NotificationHelper {
    // App-level storage/preview cap
    static let maxRemindersStored = 100
    // iOS pending limit per app (historically ~64)
    static let maxPendingPeriOS = 64

    // Remove ALL requests for this plan by id prefix
    static func cancelReminder(for plan: EventPlan) {
        let center = UNUserNotificationCenter.current()
        let prefix = "event_reminder_\(plan.id.uuidString)_"
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    // Backward compatible single API
    static func scheduleEventReminder(for plan: EventPlan, offset: TimeInterval) {
        scheduleEventReminders(for: plan, offsets: [offset])
    }

    // Multi schedule with guards: skip past, nudge near-now, hand iOS only first 64
    static func scheduleEventReminders(for plan: EventPlan, offsets: [TimeInterval]) {
        cancelReminder(for: plan)

        let center = UNUserNotificationCenter.current()
        let now = Date()

        // Convert relative offsets -> absolute fire dates, future-only, sorted
        let future = offsets
            .map { plan.date.addingTimeInterval($0) }
            .filter { $0 > now }
            .sorted()

        let toSchedule = Array(future.prefix(maxPendingPeriOS))

        for (idx, fire) in toSchedule.enumerated() {
            var triggerDate = fire
            if triggerDate.timeIntervalSince(now) < 5 {
                // useful while testing: avoid immediate drop on next runloop
                triggerDate = now.addingTimeInterval(5)
            }

            let content = UNMutableNotificationContent()
            content.title = "Upcoming Event: \(plan.name)"
            content.body = "Get ready! Your event is on \(formatted(plan.date)). Tap to check your list."
            content.sound = .default
            content.userInfo = ["eventPlanID": plan.id.uuidString]
            content.categoryIdentifier = "EVENT_REMINDER"

            let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "event_reminder_\(plan.id.uuidString)_\(idx)"

            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }

        // Optional debug: uncomment to inspect what’s pending
        /*
        center.getPendingNotificationRequests { reqs in
            let prefix = "event_reminder_\(plan.id.uuidString)_"
            let mine = reqs.filter { $0.identifier.hasPrefix(prefix) }
            print("Scheduled \(mine.count) reminders for plan \(plan.id)")
            mine.forEach {
                let when = ( $0.trigger as? UNCalendarNotificationTrigger )?.nextTriggerDate() ?? .distantPast
                print(" • \($0.identifier) @ \(when)")
            }
        }
        */
    }

    static func formatted(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

