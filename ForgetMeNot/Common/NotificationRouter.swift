import Foundation
import UserNotifications
import Combine

final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    @Published var pendingPlanID: UUID?

    private override init() { super.init() }

    // Called when user taps a delivered notification
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let idStr = response.notification.request.content.userInfo["eventPlanID"] as? String,
           let id = UUID(uuidString: idStr) {
            DispatchQueue.main.async {
                self.pendingPlanID = id
            }
        }
        completionHandler()
    }

    // Optional, show banner when foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func configureAsDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }
}
