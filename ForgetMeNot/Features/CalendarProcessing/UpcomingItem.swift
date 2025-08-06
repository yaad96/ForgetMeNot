//
//  UpcomingItem.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/5/25.
//


import EventKit

enum UpcomingItem: Identifiable {
    case event(EKEvent)
    case reminder(EKReminder)

    var id: String {
        switch self {
        case .event(let event):
            return "event-\(event.eventIdentifier ?? UUID().uuidString)"
        case .reminder(let reminder):
            return "reminder-\(reminder.calendarItemIdentifier)"
        }
    }

    var title: String {
        switch self {
        case .event(let event):
            return event.title
        case .reminder(let reminder):
            return reminder.title
        }
    }

    var notes: String? {
        switch self {
        case .event(let event):
            return event.notes
        case .reminder(let reminder):
            return reminder.notes
        }
    }

    var date: Date? {
        switch self {
        case .event(let event):
            return event.startDate
        case .reminder(let reminder):
            return reminder.dueDateComponents?.date
        }
    }

    var type: String {
        switch self {
        case .event: return "Event"
        case .reminder: return "Reminder"
        }
    }
}
