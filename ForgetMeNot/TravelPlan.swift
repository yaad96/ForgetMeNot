import Foundation
import SwiftData

@Model
class TravelPlan: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date
    @Relationship(deleteRule: .cascade) var tasks: [TravelTask]
    var reminderOffset: TimeInterval // in seconds

    init(name: String, date: Date, tasks: [TravelTask] = [], reminderOffset: TimeInterval = -3600, id: UUID = .init()) {
        self.id = id
        self.name = name
        self.date = date
        self.tasks = tasks
        self.reminderOffset = reminderOffset
    }
}

@Model
class TravelTask: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var isDone: Bool

    init(title: String, isDone: Bool = false, id: UUID = .init()) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

