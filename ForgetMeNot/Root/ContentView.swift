import SwiftUI
import SwiftData
import AVFAudio // or AVFoundation
import UIKit     // for opening Settings

// --- Path Destination Enum ---
enum AppNav: Hashable {
    case newPlan
    case allUpcoming
    case planDetail(TravelPlan)
}

struct ContentView: View {
    @Query(sort: \TravelPlan.date, order: .forward) var plans: [TravelPlan]
    @Environment(\.modelContext) private var modelContext

    @State private var navPath = NavigationPath()
    @State private var planToOpen: TravelPlan?
    @State private var newPlanParams: (planName: String?, travelDate: Date?, reminderDate: Date?, tasks: [TravelTask]?) = (nil, nil, nil, nil)

    // Talk-to-Plan: use the modular ViewModel
    @StateObject private var vm = TalkToPlanViewModel(apiKey: APIKeyLoader.openAIKey)
    
    @ViewBuilder
    private var generatingOverlay: some View {
        Color.black.opacity(0.07).ignoresSafeArea()
        ProgressView("Generating plan with ChatGPT…")
            .padding(20)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(radius: 10)
    }

    @ViewBuilder
    private var mainList: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Card
                VStack(spacing: 4) {
                    Text("🧳ForgetMeNot")
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .foregroundColor(.accentColor)
                        .shadow(color: .accentColor.opacity(0.04), radius: 2, y: 1)
                        .padding(.bottom, 2)
                    Text("Let your iPhone remember important details!")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.72))
                        .shadow(color: .accentColor.opacity(0.09), radius: 5, y: 2)
                )
                .padding(.horizontal, 14)
                .padding(.top, 22)

                // Sleek Modern Buttons
                HStack(spacing: 10) {
                    Button {
                        navPath.append(AppNav.newPlan)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                            Text("New Plan")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor.opacity(0.15), Color.blue.opacity(0.12)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .foregroundColor(.accentColor)
                    .buttonStyle(.plain)

                    Button {
                        navPath.append(AppNav.allUpcoming)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.stack")
                            Text("From Calendar")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.14), Color.accentColor.opacity(0.13)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .foregroundColor(.accentColor)
                    .buttonStyle(.plain)
                }
                .padding(.top, 14)
                .padding(.horizontal, 18)

                // Voice Button Row (Talk-to-Plan)
                HStack(spacing: 10) {
                    Button {
                        vm.onTapVoice()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mic.circle.fill")
                            Text("Talk to Make Plans!")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.14), Color.accentColor.opacity(0.13)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .foregroundColor(.accentColor)
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
                .padding(.horizontal, 18)

                // Sections
                let incompletePlans: [TravelPlan] = plans.filter { !$0.isCompleted }
                let completedPlans:   [TravelPlan] = plans.filter {  $0.isCompleted }

                if plans.isEmpty {
                    VStack {
                        Spacer(minLength: 60)
                        Text("No travel plans yet.\nTap 'Create a New Travel Plan' to get started!")
                            .font(.title3.weight(.medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    // Incomplete
                    if !incompletePlans.isEmpty {
                        SectionHeader(text: "Upcoming Plans", systemImage: "clock")
                            .padding(.top , 28)
                            .padding(.bottom, 8)
                            .padding(.leading, 8)
                        VStack(spacing: 14) {
                            ForEach(incompletePlans) { plan in
                                PlanCard(
                                    plan: plan,
                                    isCompleted: false,
                                    onTap: {
                                        navPath.append(AppNav.planDetail(plan))
                                    },
                                    onDelete: { deepDeleteTravelPlan(plan, modelContext: modelContext) }
                                )
                            }
                        }
                        .padding(.horizontal, 14)
                    }

                    // Completed
                    if !completedPlans.isEmpty {
                        SectionHeader(text: "Completed", systemImage: "checkmark.seal")
                            .padding(.top, incompletePlans.isEmpty ? 36 : 24)
                            .padding(.leading, 8)
                        VStack(spacing: 14) {
                            ForEach(completedPlans) { plan in
                                PlanCard(
                                    plan: plan,
                                    isCompleted: true,
                                    onTap: {
                                        navPath.append(AppNav.planDetail(plan))
                                    },
                                    onDelete: { deepDeleteTravelPlan(plan, modelContext: modelContext) }
                                )
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 16)
                    }
                }

                Spacer(minLength: 60)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .blur(radius: vm.isGeneratingPlan ? 2 : 0)
        .disabled(vm.isGeneratingPlan)
    }


    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                mainList
                if vm.isGeneratingPlan { generatingOverlay }
            }

            // Recorder
            .sheet(isPresented: $vm.showVoiceSheet) {
                VoiceRecorderSheet(
                    onFinish: { url in vm.didFinishRecording(url: url) },
                    onCancel: { vm.didCancelRecording() }
                )
            }

            // Progress
            .sheet(isPresented: $vm.isTranscribing) {
                TranscribeProgressView()
                    .interactiveDismissDisabled(true)
            }

            // Confirm and edit transcript
            .sheet(isPresented: $vm.showConfirmTranscript) {
                ConfirmTranscriptSheet(
                    text: $vm.transcript,
                    onUse: { vm.confirmAndGenerate() },          // <— was vm.generateSmartPlan()
                    onCancel: { vm.showConfirmTranscript = false }
                )
            }

            // Mic permission alert
            .alert("Microphone Access Needed", isPresented: $vm.showMicDeniedAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } message: {
                Text("To record your voice, allow mic access in Settings for ForgetMeNot.")
            }

            // Generic error alert
            .alert(
                "Error",
                isPresented: Binding(
                    get: { vm.error != nil },
                    set: { if !$0 { vm.error = nil } }
                )
            ) {
                Button("OK") { vm.error = nil }
            } message: {
                Text(vm.error ?? "")
            }

            // Existing navigation destinations
            .navigationDestination(for: AppNav.self) { destination in
                switch destination {
                case .newPlan:
                    NewTravelPlanView { newPlan in
                        if let plan = newPlan {
                            navPath.removeLast(navPath.count)
                            navPath.append(AppNav.planDetail(plan))
                        } else {
                            navPath.removeLast(navPath.count)
                        }
                    }

                case .allUpcoming:
                    AllUpcomingView(
                        calendarManager: CalendarManager(),
                        navPath: $navPath
                    )
                case .planDetail(let plan):
                    TravelPlanDetailView(plan: plan)
                }
            }

            // Navigate to NewTravelPlanView with pending values from VM
            .navigationDestination(isPresented: $vm.isNewPlanActive) {
                NewTravelPlanView(
                    planName: vm.pendingPlanName,
                    travelDate: vm.pendingTravelDate,
                    reminderDate: vm.pendingReminderDate,
                    tasks: vm.pendingTasks
                ) { newPlan in
                    if let plan = newPlan {
                        navPath.removeLast(navPath.count)
                        navPath.append(AppNav.planDetail(plan))
                    } else {
                        navPath.removeLast(navPath.count)
                    }
                }
            }
        }
    }
}


// MARK: - Section Header
struct SectionHeader: View {
    let text: String
    let systemImage: String
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
                .font(.system(size: 15, weight: .semibold))
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.leading, 2)
        .padding(.bottom, 3)
    }
}


// MARK: - Plan Card
struct PlanCard: View {
    let plan: TravelPlan
    let isCompleted: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isCompleted ? Color.green.opacity(0.08) : Color.blue.opacity(0.06))
                    .frame(width: 42, height: 42)
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "hourglass.bottomhalf.filled")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(isCompleted ? .green : .blue)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(plan.date, style: .date)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray.opacity(0.6))
                .font(.system(size: 14, weight: .semibold))
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.75))
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(.thinMaterial)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

