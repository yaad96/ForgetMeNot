import SwiftUI
import SwiftData
import UserNotifications
import UIKit

@main
struct ForgetMeNotApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TravelPlan.self,
            TravelTask.self,
            SubjectImage.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [modelConfiguration])
    }()

    init() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                print("Notification permission granted: \(granted)")
            }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(sharedModelContainer)
        }
    }
}

