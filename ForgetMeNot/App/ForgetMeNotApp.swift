import SwiftUI
import SwiftData
import UserNotifications
import UIKit

@main
struct ForgetMeNotApp: App {
    // SwiftData container (unchanged)
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            EventPlan.self,
            EventTask.self,
            SubjectImage.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [modelConfiguration])
    }()

    init() {
        // One line does it all: sets UNUserNotificationCenter.delegate,
        // registers categories, and requests permission.
        NotificationRouter.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
                // Optional, but useful if you want to react to taps
                // on notifications inside your view layer:
                .environmentObject(NotificationRouter.shared)
        }
    }
}

