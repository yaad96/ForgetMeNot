//
//  NotificationRouter.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/24/25.
//


import Foundation
import UserNotifications
import Combine

final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()
    @Published var pendingPlanID: UUID?

    private override init() { super.init() }

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Category for future actions
        let cat = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([cat])

        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, err in
            print("Notifications auth granted:", granted, "error:", err?.localizedDescription ?? "nil")
        }
    }

    // Foreground banners
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Tap routing
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        if let idStr = response.notification.request.content.userInfo["eventPlanID"] as? String,
           let id = UUID(uuidString: idStr) {
            DispatchQueue.main.async { self.pendingPlanID = id }
        }
        completionHandler()
    }
}

