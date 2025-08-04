import Foundation
import SwiftData

@Model
class TravelPlan: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date
    @Relationship(deleteRule: .cascade) var tasks: [TravelTask]
    var reminderOffset: TimeInterval
    var isCompleted: Bool = false   // <-- ADD THIS FIELD

    init(name: String,
         date: Date,
         tasks: [TravelTask] = [],
         reminderOffset: TimeInterval = -3600,
         id: UUID = .init(),
         isCompleted: Bool = false) {     // <-- ADD THIS TO INIT
        self.id = id
        self.name = name
        self.date = date
        self.tasks = tasks
        self.reminderOffset = reminderOffset
        self.isCompleted = isCompleted
    }
}


@Model
class TravelTask: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var subjectImageID: UUID?
    var isCompleted: Bool = false

    init(title: String,
         subjectImageID: UUID? = nil,
         id: UUID = .init()) {
        self.id = id
        self.title = title
        self.subjectImageID = subjectImageID
    }
}

