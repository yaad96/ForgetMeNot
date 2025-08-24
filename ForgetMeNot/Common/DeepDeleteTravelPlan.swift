import SwiftData
import Foundation  // <-- This is needed for UUID

func deepDeleteEventPlan(_ plan: EventPlan, modelContext: ModelContext) {
    // 1. Cancel notification(s) for the plan
    NotificationHelper.cancelReminder(for: plan)
    
    // 2. Delete all associated SubjectImages (orphans) from tasks
    let subjectImageIDs: [UUID] = plan.tasks.compactMap { $0.subjectImageID }
    if !subjectImageIDs.isEmpty {
        for imageID in subjectImageIDs {
            let request = FetchDescriptor<SubjectImage>(predicate: #Predicate { $0.id == imageID })
            if let subjectImage = try? modelContext.fetch(request).first {
                modelContext.delete(subjectImage)
            }
        }
    }
    // 3. Delete the plan (cascades to tasks)
    modelContext.delete(plan)
}

