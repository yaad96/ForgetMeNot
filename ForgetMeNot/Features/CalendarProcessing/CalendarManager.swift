//
//  CalendarManager.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/5/25.
//


import EventKit
import Combine

func isRelevantReminder(_ reminder: EKReminder) -> Bool {
    guard let dueDate = reminder.dueDateComponents?.date else { return false }
    let now = Date()
    let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: now)!
    
    // Not repeating
    if reminder.recurrenceRules == nil || reminder.recurrenceRules?.isEmpty == true {
        return dueDate >= now && dueDate <= oneMonthLater
    }
    // Repeats, check first occurrence and recurrence end
    if let rules = reminder.recurrenceRules, let rule = rules.first {
        if let end = rule.recurrenceEnd?.endDate {
            // Only if dueDate in window AND recurrence ends within window
            return (dueDate >= now && dueDate <= oneMonthLater) && (end <= oneMonthLater)
        } else {
            // Perpetual, but only show if FIRST due is in window
            return dueDate >= now && dueDate <= oneMonthLater
        }
    }
    return false
}



class CalendarManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var events: [EKEvent] = []
    @Published var reminders: [EKReminder] = [] 
    @Published var permissionDenied = false
    @Published var loading = false
    
    var upcomingItems: [UpcomingItem] {
        let eventItems = events.map { UpcomingItem.event($0) }
        let reminderItems = reminders
            .compactMap { $0.dueDateComponents?.date != nil ? UpcomingItem.reminder($0) : nil }
        let allItems = eventItems + reminderItems
        // Sort by date, nil dates go last
        return allItems.sorted { (a, b) in
            guard let d1 = a.date else { return false }
            guard let d2 = b.date else { return true }
            return d1 < d2
        }
    }
    
    

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
    
    func requestAndFetchReminders() {
        eventStore.requestAccess(to: .reminder) { [weak self] granted, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.permissionDenied = !granted // Optionally track reminder permissions separately
            }
            guard granted else { return }
            let now = Date()
            let oneMonthLater = Calendar.current.date(byAdding: .month, value: 1, to: now)!
            let predicate = self.eventStore.predicateForReminders(in: nil)
            self.eventStore.fetchReminders(matching: predicate) { reminders in
                let filtered = reminders?.filter { rem in
                    isRelevantReminder(rem)
                } ?? []

                DispatchQueue.main.async {
                    self.reminders = filtered
                }
            }
        }
    }
}



