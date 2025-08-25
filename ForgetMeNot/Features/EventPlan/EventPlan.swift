import Foundation
import SwiftData

@Model
class EventPlan: Identifiable {
    @Attribute(.unique) var id: UUID
    var name: String
    var date: Date
    @Relationship(deleteRule: .cascade) var tasks: [EventTask]

    // Legacy single reminder
    var reminderOffset: TimeInterval

    // Store multi-reminders as Data, JSON-encoded [Double]
    var reminderOffsetsBlob: Data? = nil

    // Public API stays as [TimeInterval]
    var reminderOffsets: [TimeInterval] {
        get {
            guard let blob = reminderOffsetsBlob else { return [] }
            return (try? JSONDecoder().decode([Double].self, from: blob)) ?? []
        }
        set {
            reminderOffsetsBlob = try? JSONEncoder().encode(newValue)
        }
    }

    var isCompleted: Bool = false

    init(name: String,
         date: Date,
         tasks: [EventTask] = [],
         reminderOffset: TimeInterval = -3600,
         reminderOffsets: [TimeInterval] = [],
         id: UUID = .init(),
         isCompleted: Bool = false) {
        self.id = id
        self.name = name
        self.date = date
        self.tasks = tasks
        self.reminderOffset = reminderOffset
        self.isCompleted = isCompleted
        // seed the blob
        self.reminderOffsets = reminderOffsets
    }

    /// All reminder offsets, using multi if present, else legacy single.
    var allReminderOffsets: [TimeInterval] {
        let multi = reminderOffsets
        return multi.isEmpty ? [reminderOffset] : multi
    }
}

@Model
class EventTask: Identifiable {
    @Attribute(.unique) var id: UUID
    var title: String
    var subjectImageID: UUID?
    var isCompleted: Bool = false

    init(title: String, subjectImageID: UUID? = nil, id: UUID = .init()) {
        self.id = id
        self.title = title
        self.subjectImageID = subjectImageID
    }
}

