import SwiftUI
import SwiftData
import AVFAudio // or AVFoundation
import UIKit     // for opening Settings

// --- Path Destination Enum ---
enum AppNav: Hashable {
    case newPlan
    case allUpcoming
    case planDetail(EventPlan)
}

struct ContentView: View {
    @Query(sort: \EventPlan.date, order: .forward) var plans: [EventPlan]
    @Environment(\.modelContext) private var modelContext

    @State private var navPath = NavigationPath()
    @State private var planToOpen: EventPlan?
    @State private var newPlanParams: (planName: String?, eventDate: Date?, reminderDate: Date?, tasks: [EventTask]?) = (nil, nil, nil, nil)

    // Talk-to-Plan: use the modular ViewModel
    @StateObject private var vm = TalkToPlanViewModel(apiKey: APIKeyLoader.openAIKey)
    
    @State private var showWalkthrough = false
    
    @StateObject private var router = NotificationRouter.shared
    
    //Photo-to-plan
    @StateObject private var photoVM = PhotoToPlanViewModel(apiKey: APIKeyLoader.openAIKey) // :contentReference[oaicite:15]{index=15}

    @State private var showPhotoSourcePicker = false
    @State private var activePhotoPicker: ImagePickerSheet?

    
    // MARK: - Action tile button style

    struct ActionTileStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .shadow(color: .black.opacity(configuration.isPressed ? 0.08 : 0.15),
                        radius: configuration.isPressed ? 6 : 12, y: 5)
                .animation(.spring(response: 0.28, dampingFraction: 0.85), value: configuration.isPressed)
        }
    }

    // MARK: - Single tile

    struct ActionTile: View {
        let title: String
        let systemImage: String
        let gradient: [Color]
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.ultraThinMaterial)
                            .opacity(0.2)
                            .frame(width: 44, height: 44)
                            .offset(x: systemImage == "calendar" ? 10.75 : 0)

                        Image(systemName: systemImage)
                            .font(.system(size: 22, weight: .semibold))
                            .offset(x: systemImage == "calendar" ? 10.75 : 0) // ~1 pt is usually enough
                            .padding(5)

                    }
                    .padding(.top, 8)  // ⬅️ pushes the icon down from the top edge

                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                        .offset(x: systemImage == "calendar" ? 3.75 : 0)

                    Spacer(minLength: 0)
                }
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(colors: gradient,
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.15), lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel(Text(title))
            }
            .buttonStyle(ActionTileStyle())
        }
    }

    // MARK: - Section with 4 tiles

    struct CreatePlanFromSection: View {
        let onPhoto: () -> Void
        let onSpeech: () -> Void
        let onCalendar: () -> Void
        let onManual: () -> Void

        // Adaptive layout: 2 columns on phones, more on wider screens
        private var columns: [GridItem] {
            [GridItem(.adaptive(minimum: 150, maximum: 240), spacing: 12, alignment: .top)]
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("Create plan from")
                        .font(.title3.weight(.semibold))
                    Spacer()
                }
                .padding(.horizontal, 4)

                LazyVGrid(columns: columns, spacing: 12) {
                    ActionTile(
                        title: "Photo",
                        systemImage: "photo.circle.fill",
                        gradient: [Color.purple, Color.pink.opacity(0.85)]
                    ) { onPhoto() }

                    ActionTile(
                        title: "Speech",
                        systemImage: "waveform.circle.fill",
                        gradient: [Color.orange, Color.red.opacity(0.85)]
                    ) { onSpeech() }

                    ActionTile(
                        title: "Calendar",
                        systemImage: "calendar",
                        gradient: [Color.indigo, Color.blue.opacity(0.85)]
                    ) { onCalendar() }

                    ActionTile(
                        title: "Manual",
                        systemImage: "plus.square.on.square",
                        gradient: [Color.green, Color.teal.opacity(0.85)]
                    ) { onManual() }
                }
            }
            .padding(.vertical, 8)
        }
    }



    
    @ViewBuilder
    private var generatingOverlay: some View {
        Color.black.opacity(0.07).ignoresSafeArea()
        ProgressView("Generating plan with AI…")
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
                    Text("Unforget")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.accentColor)
                        .shadow(color: .accentColor.opacity(0.04), radius: 2, y: 1)
                        .padding(.bottom, 2)
                    Text("Let your iPhone remember everything.")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14, weight: .medium))
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
                
                CreatePlanFromSection(
                    onPhoto: { showPhotoSourcePicker = true },
                    onSpeech: { vm.onTapVoice() },
                    onCalendar: { navPath.append(AppNav.allUpcoming) },
                    onManual: { navPath.append(AppNav.newPlan) }
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)


                // Sections
                let incompletePlans: [EventPlan] = plans.filter { !$0.isCompleted }
                let completedPlans:   [EventPlan] = plans.filter {  $0.isCompleted }

                if plans.isEmpty {
                    VStack {
                        Spacer(minLength: 60)
                        Text("No event plans yet.\nTap Any of the options above to get started.")
                            .font(.title3.weight(.medium))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                } else {
                    // Incomplete
                    if !incompletePlans.isEmpty {
                        SectionHeader(text: "Upcoming Events", systemImage: "clock")
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
                                    onDelete: { deepDeleteEventPlan(plan, modelContext: modelContext) }
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
                                    onDelete: { deepDeleteEventPlan(plan, modelContext: modelContext) }
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
        .blur(radius: vm.isGeneratingPlan || photoVM.isGenerating ? 2 : 0)
        .disabled(vm.isGeneratingPlan || photoVM.isGenerating)
    }
    
    private struct WalkthroughButton: View {
        var action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: "questionmark.circle.fill")
                        .imageScale(.medium)
                    Text("Walkthrough")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 0.8)
                )
                .shadow(radius: 1.5, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open walkthrough")
        }
    }
    
    private struct InlineImageSourcePicker: View {
        var onSourcePicked: (UIImagePickerController.SourceType) -> Void
        @Environment(\.dismiss) private var dismiss

        private var cameraAvailable: Bool {
            UIImagePickerController.isSourceTypeAvailable(.camera)
        }

        var body: some View {
            VStack(spacing: 16) {

                Text("Add an event poster, flyer, or leaflet image.")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)   // shrinks if needed
                    .allowsTightening(true)


                VStack(spacing: 10) {
                    Button {
                        guard cameraAvailable else { return }
                        onSourcePicked(.camera)
                        dismiss()
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!cameraAvailable)
                    .opacity(cameraAvailable ? 1 : 0.5)
                    .accessibilityHint(cameraAvailable ? "Opens camera" : "Camera not available on this device")

                    Button {
                        onSourcePicked(.photoLibrary)
                        dismiss()
                    } label: {
                        Label("Choose From Library", systemImage: "photo.fill.on.rectangle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                    .padding(.top, 2)
                }
            }
            .padding(20)
        }
    }



    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                mainList
                if vm.isGeneratingPlan || photoVM.isGenerating { generatingOverlay }
                
            }
            
            .safeAreaInset(edge: .bottom) {  // keeps the button off the home indicator
                HStack {
                    Spacer()
                    WalkthroughButton {
                        showWalkthrough = true
                    }
                    .padding(.trailing, 16)
                }
                .padding(.bottom, 8)
            }
            .sheet(isPresented: $showWalkthrough) {
                WalkthroughView()
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
            
            // Choose camera or gallery
            .sheet(isPresented: $showPhotoSourcePicker) {
                InlineImageSourcePicker { source in
                    activePhotoPicker = (source == .camera ? .camera : .photoLibrary)
                    // dismiss is handled inside the inline picker
                }
                .presentationDetents([.fraction(0.35), .medium])
                .presentationDragIndicator(.visible)
            }


            // Then pick the actual image
            .sheet(item: $activePhotoPicker) { which in
                FMNImagePicker(sourceType: which == .camera ? .camera : .photoLibrary) { img in
                    if let ui = img {
                        photoVM.selectedImage = ui
                        photoVM.showConfirmImage = true
                    }
                    activePhotoPicker = nil
                }
            }
            
            .sheet(isPresented: $photoVM.showConfirmImage) {
                if let img = photoVM.selectedImage {
                    PhotoPlanConfirmSheet(
                        image: img,
                        onUse: { photoVM.confirmAndGenerate() },
                        onCancel: {
                            photoVM.showConfirmImage = false
                            photoVM.selectedImage = nil
                        }
                    )
                    .interactiveDismissDisabled(photoVM.isGenerating)
                }
            }

            .alert("Photo Analysis Failed", isPresented: Binding(
                get: { photoVM.error != nil },
                set: { if !$0 { photoVM.error = nil } }
            )) {
                Button("OK") { photoVM.error = nil }
            } message: {
                Text(photoVM.error ?? "")
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
                    NewEventPlanView { newPlan in
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
                    EventPlanDetailView(plan: plan)
                }
            }

            // Navigate to NewEventPlanView with pending values from VM
            .navigationDestination(isPresented: $vm.isNewPlanActive) {
                NewEventPlanView(
                    planName: vm.pendingPlanName,
                    eventDate: vm.pendingEventDate,
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
            
            .navigationDestination(isPresented: $photoVM.isNewPlanActive) {
                NewEventPlanView(
                    planName: photoVM.pendingPlanName,
                    eventDate: photoVM.pendingEventDate,
                    reminderDate: photoVM.pendingReminderDate,
                    tasks: photoVM.pendingTasks
                ) { newPlan in
                    if let plan = newPlan {
                        navPath.removeLast(navPath.count)
                        navPath.append(AppNav.planDetail(plan))
                    } else {
                        navPath.removeLast(navPath.count)
                    }
                }
            }

            
            .onReceive(router.$pendingPlanID.compactMap { $0 }) { id in
                // find the plan in your SwiftData query
                if let plan = plans.first(where: { $0.id == id }) {
                    // reset to root then push to detail
                    navPath.removeLast(navPath.count)
                    navPath.append(AppNav.planDetail(plan))
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
    let plan: EventPlan
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

