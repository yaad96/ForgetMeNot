//
//  PhotoToPlanViewModel.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/25/25.
//


// PhotoToPlanViewModel.swift
import Foundation
import SwiftUI

@MainActor
final class PhotoToPlanViewModel: ObservableObject {
    // UI
    @Published var selectedImage: UIImage?
    @Published var showConfirmImage = false
    @Published var isGenerating = false
    @Published var error: String?

    // Navigation payload (match TalkToPlanViewModel)
    @Published var isNewPlanActive = false
    @Published var pendingPlanName = ""
    @Published var pendingEventDate = Date()
    @Published var pendingReminderDate = Date()
    @Published var pendingTasks: [EventTask] = []

    private let planGen: PlanGeneratorService

    init(apiKey: String) {
        self.planGen = PlanGeneratorService(apiKey: apiKey) // same model and headers
    }

    func confirmAndGenerate() {
        guard let img = selectedImage else { return }
        showConfirmImage = false
        isGenerating = true
        Task { await generatePlan(img) }
    }

    private func generatePlan(_ image: UIImage) async {
        defer { isGenerating = false }
        do {
            let plan = try await planGen.generate(from: image)
            let iso = ISO8601DateFormatter()
            let event = iso.date(from: plan.date) ?? .now
            let notif = iso.date(from: plan.reminder_date) ?? event
            pendingPlanName = plan.title.isEmpty ? "Event" : plan.title
            pendingEventDate = event
            pendingReminderDate = notif
            pendingTasks = plan.tasks.map { EventTask(title: $0) }
            isNewPlanActive = true
        } catch {
            self.error = error.localizedDescription
            // allow a path forward with defaults
            pendingPlanName = "Event"
            pendingEventDate = .now
            pendingReminderDate = .now
            pendingTasks = []
            isNewPlanActive = true
        }
    }
}
