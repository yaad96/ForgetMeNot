import Foundation
import UserNotifications

struct NotificationHelper {
    /// Cancels any scheduled notification for the given plan.
    static func cancelReminder(for plan: TravelPlan) {
        let center = UNUserNotificationCenter.current()
        let identifier = "travel_reminder_\(plan.id)"
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    /// Schedules a travel reminder for the given plan at the given offset.
    /// If a reminder already exists, it is cancelled and replaced.
    static func scheduleTravelReminder(for plan: TravelPlan, offset: TimeInterval) {
        cancelReminder(for: plan) // Always cancel old first
        
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

