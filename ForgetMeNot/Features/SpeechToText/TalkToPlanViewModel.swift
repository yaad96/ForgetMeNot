//
//  TalkToPlanViewModel.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/19/25.
//


import Foundation
import SwiftUI

@MainActor
final class TalkToPlanViewModel: ObservableObject {
    // UI state
    @Published var showMicDeniedAlert = false
    @Published var showVoiceSheet = false
    @Published var isTranscribing = false
    @Published var transcript: String = ""
    @Published var showConfirmTranscript = false
    @Published var error: String?
    @Published var lastRecordingURL: URL?

    // New plan navigation payload
    @Published var isNewPlanActive = false
    @Published var pendingPlanName = ""
    @Published var pendingTravelDate = Date()
    @Published var pendingReminderDate = Date()
    @Published var pendingTasks: [TravelTask] = []
    
    @Published var isGeneratingPlan = false


    // deps
    private let mic = MicPermissionService()
    private let stt: OpenAITranscriptionService
    private let planGen: PlanGeneratorService

    init(apiKey: String) {
        self.stt = OpenAITranscriptionService(apiKey: apiKey)
        self.planGen = PlanGeneratorService(apiKey: apiKey)
    }

    // Entry point from the voice button
    func onTapVoice() {
        Task {
            let status = await mic.request()
            if status == .granted { showVoiceSheet = true }
            else { showMicDeniedAlert = true }
        }
    }

    func didFinishRecording(url: URL) {
        lastRecordingURL = url
        showVoiceSheet = false
        Task { await transcribe(url: url) }
    }

    func didCancelRecording() {
        showVoiceSheet = false
    }

    private func transcribe(url: URL) async {
        isTranscribing = true
        do {
            let text = try await stt.transcribe(fileURL: url)
            print("OpenAI transcript:", text)
            transcript = text
            showConfirmTranscript = true
        } catch {
            self.error = error.localizedDescription
            print("OpenAI STT error:", error.localizedDescription)
        }
        isTranscribing = false
        if let url = lastRecordingURL {
            try? FileManager.default.removeItem(at: url)
            lastRecordingURL = nil
        }
    }

    func generateSmartPlan() {
        Task {
            do {
                let plan = try await planGen.generate(from: transcript)
                let iso = ISO8601DateFormatter()
                let travel = iso.date(from: plan.date) ?? .now
                let notif  = iso.date(from: plan.reminder_date) ?? travel
                pendingPlanName = plan.title.isEmpty ? "Trip" : plan.title
                pendingTravelDate = travel
                pendingReminderDate = notif
                pendingTasks = plan.tasks.map { TravelTask(title: $0) }
                isGeneratingPlan = false
                isNewPlanActive = true
            } catch {
                print("Chat plan error:", error.localizedDescription)
                self.error = error.localizedDescription
                // allow navigation with sane defaults if you like
                pendingPlanName = "Trip"
                pendingTravelDate = .now
                pendingReminderDate = .now
                pendingTasks = []
                isGeneratingPlan = false
                isNewPlanActive = true
            }
        }
    }
    
    func confirmAndGenerate() {
        showConfirmTranscript = false
        isGeneratingPlan = true
        generateSmartPlan()
    }


}
