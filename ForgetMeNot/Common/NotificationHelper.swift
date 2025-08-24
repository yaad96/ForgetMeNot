import Foundation
import UserNotifications

struct NotificationHelper {
    /// Cancels any scheduled notification for the given plan.
    static func cancelReminder(for plan: EventPlan) {
        let center = UNUserNotificationCenter.current()
        let identifier = "event_reminder_\(plan.id)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    /// Schedules a event reminder for the given plan at the given offset.
    /// If a reminder already exists, it is cancelled and replaced.
    // NotificationHelper.swift
    static func scheduleEventReminder(for plan: EventPlan, offset: TimeInterval) {
        cancelReminder(for: plan)

        let center = UNUserNotificationCenter.current()
        let triggerDate = plan.date.addingTimeInterval(offset)
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Event: \(plan.name)"
        content.body = "Get ready! Your event is on \(formatted(plan.date)). Tap to check your list."
        content.sound = .default

        // ✅ carry the plan id so we can deep-link on tap
        content.userInfo = ["eventPlanID": plan.id.uuidString]
        content.categoryIdentifier = "EVENT_REMINDER"

        let triggerComponents = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second],
                                                                from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "event_reminder_\(plan.id)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    
    static func formatted(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

