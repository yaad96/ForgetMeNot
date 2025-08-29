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
        let center = UNUserNotificationCenter.current()
        let prefix = "event_reminder_\(plan.id.uuidString)_"
        
        // Chain operations to avoid race conditions
        center.getPendingNotificationRequests { reqs in
            // First cancel existing notifications
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            
            // Then schedule new ones (now guaranteed to be after cancellation)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.scheduleNewEventReminders(for: plan, offsets: offsets)
            }
        }
    }

    private static func scheduleNewEventReminders(for plan: EventPlan, offsets: [TimeInterval]) {
        let center = UNUserNotificationCenter.current()
        let now = Date()
        
        let future = offsets
            .map { plan.date.addingTimeInterval($0) }
            .filter { $0 > now }
            .sorted()
            
        let toSchedule = Array(future.prefix(maxPendingPeriOS))
        
        for (idx, fire) in toSchedule.enumerated() {
            var triggerDate = fire
            if triggerDate.timeIntervalSince(now) < 10 { // Increased buffer
                triggerDate = now.addingTimeInterval(10)
            }
            
            let content = UNMutableNotificationContent()
            content.title = "🗓️ Plan Reminder: \(plan.name)"
            content.subtitle = "⏳ Plan Date: \(formatted(plan.date)) "
            content.body = "Tap to ensure all arrangements are finalized."
            content.sound = .default
            content.userInfo = ["eventPlanID": plan.id.uuidString]
            content.categoryIdentifier = "EVENT_REMINDER"
            
            let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: triggerDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let id = "event_reminder_\(plan.id.uuidString)_\(idx)"
            
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(request) { error in
                if let error = error {
                    print("⚠️ Failed to schedule notification: \(error)")
                }
            }
        }
    }

    
    // MARK: - Task reminder helpers

    static func cancelTaskReminder(for plan: EventPlan, task: EventTask) {
        let center = UNUserNotificationCenter.current()
        let prefix = "task_reminder_\(plan.id.uuidString)_\(task.id.uuidString)"
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
    }

    static func scheduleTaskReminder(for plan: EventPlan, task: EventTask) {
        guard let when = task.reminderAt else { return }
        let now = Date()
        guard when > now, when <= plan.date else { return }
        
        let center = UNUserNotificationCenter.current()
        let prefix = "task_reminder_\(plan.id.uuidString)_\(task.id.uuidString)"
        
        // Chain operations properly
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.scheduleNewTaskReminder(for: plan, task: task, when: when)
            }
        }
    }

    private static func scheduleNewTaskReminder(for plan: EventPlan, task: EventTask, when: Date) {
        let center = UNUserNotificationCenter.current()
        let now = Date()
        
        var triggerDate = when
        if triggerDate.timeIntervalSince(now) < 10 {
            triggerDate = now.addingTimeInterval(10)
        }
        
        let content = UNMutableNotificationContent()
        content.title = "🎯 Task Reminder: \(task.title)"      // put the task in the prominent spot
        content.subtitle = "📅 Plan: \(plan.name)"                     // optional, shows under the title
        content.body = "Time to tackle this task.\nLet’s get it done!"  // newline works here
        content.sound = .default
        content.userInfo = [
            "eventPlanID": plan.id.uuidString,
            "eventTaskID": task.id.uuidString
        ]
        content.categoryIdentifier = "TASK_REMINDER"
        
        let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute,.second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = "task_reminder_\(plan.id.uuidString)_\(task.id.uuidString)"
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { error in
            if let error = error {
                print("⚠️ Failed to schedule task notification: \(error)")
            }
        }
    }

    
    // Cancel ALL task reminders for a plan (handles deleted tasks too)
    static func cancelAllTaskReminders(for plan: EventPlan) {
        let center = UNUserNotificationCenter.current()
        let prefix = "task_reminder_\(plan.id.uuidString)_"
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.compactMap { req in
                req.identifier.hasPrefix(prefix) ? req.identifier : nil
            }
            if !ids.isEmpty { center.removePendingNotificationRequests(withIdentifiers: ids) }
        }
    }

    static func rescheduleAllTaskReminders(for plan: EventPlan) {
        cancelAllTaskReminders(for: plan)
        for t in plan.tasks where t.reminderAt != nil {
            scheduleTaskReminder(for: plan, task: t)
        }
    }



    static func formatted(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

