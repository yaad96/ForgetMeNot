import Foundation
import UserNotifications

struct NotificationHelper {
    static func scheduleTravelReminder(for plan: TravelPlan, offset: TimeInterval) {
        let center = UNUserNotificationCenter.current()
        let triggerDate = plan.date.addingTimeInterval(offset)
        let content = UNMutableNotificationContent()
        content.title = "Upcoming Trip: \(plan.name)"
        content.body = "Get ready! Your travel is on \(formatted(plan.date)). Tap to check your list."
        content.sound = .default

        let triggerComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)

        let request = UNNotificationRequest(
            identifier: "travel_reminder_\(plan.id)",
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

