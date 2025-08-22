import SwiftUI
import SwiftData
import UIKit

extension UIImage {
    func resized(maxDim: CGFloat) -> UIImage {
        let width = size.width
        let height = size.height
        var newWidth: CGFloat
        var newHeight: CGFloat
        if width > height {
            newWidth = maxDim
            newHeight = height * (maxDim / width)
        } else {
            newHeight = maxDim
            newWidth = width * (maxDim / height)
        }
        let newSize = CGSize(width: newWidth, height: newHeight)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage ?? self
    }
}

struct NewTravelPlanView: View {
    init(
        planName: String = "",
        travelDate: Date = .now.addingTimeInterval(86400),
        reminderDate: Date = .now.addingTimeInterval(43200),
        tasks: [TravelTask] = [TravelTask(title: "Collect keys"), TravelTask(title: "Pack passport")],
        onDone: @escaping (TravelPlan?) -> Void
    ) {
        self.onDone = onDone
        _planName = State(initialValue: planName)
        _travelDate = State(initialValue: travelDate)
        _reminderDate = State(initialValue: reminderDate)
        _tasks = State(initialValue: tasks)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query var subjects: [SubjectImage]

    // Image attach states
    @State private var showImageSourceDialog = false
    @State private var activeImagePickerSheet: ImagePickerSheet?
    @State private var imageToLift: UIImage?
    @State private var showImageLift = false
    @State private var showSubjectPreview: SubjectImage?

    // Plan fields
    @State private var planName: String = ""
    @State private var travelDate: Date = .now.addingTimeInterval(86400)
    @State private var reminderDate: Date = .now.addingTimeInterval(43200)
    @State private var tasks: [TravelTask] = [
        TravelTask(title: "Collect keys"),
        TravelTask(title: "Pack passport")
    ]
    @State private var showNameError = false

    // Row index reused for image or voice flows
    @State private var editingTaskIndex: Int?

    // Voice-to-task states
    @State private var showTaskVoiceSheet = false
    @State private var isTaskTranscribing = false
    @State private var showConfirmTaskTranscript = false
    @State private var taskTranscript: String = ""
    @State private var lastTaskRecordingURL: URL?
    @State private var showMicDeniedAlert = false
    @State private var voiceError: String?

    // Services
    private let mic = MicPermissionService()
    private let stt = OpenAITranscriptionService(apiKey: APIKeyLoader.openAIKey)

    var onDone: (TravelPlan?) -> Void

    // --- Small helper to avoid solver churn on partial ranges
    @ViewBuilder
    private func ReminderSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reminder")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
            let upper = travelDate
            DatePicker(
                "",
                selection: $reminderDate,
                in: ...upper,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
    }

    // --- Extracted row to keep ForEach closure tiny (same UI)
    @ViewBuilder
    private func TaskRow(_ idx: Int) -> some View {
        HStack(alignment: .center, spacing: 11) {
            // SUBJECT IMAGE THUMBNAIL or camera placeholder
            if let id = tasks[idx].subjectImageID,
               let subj = subjects.first(where: { $0.id == id }),
               let thumb = subj.thumbnail {
                Button { showSubjectPreview = subj } label: {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1.2)
                        )
                        .shadow(color: Color.black.opacity(0.10), radius: 5, y: 1)
                        .padding(.trailing, 1)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    editingTaskIndex = idx
                    showImageSourceDialog = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(Color(.systemGray5))
                            .frame(width: 40, height: 40)
                        Image(systemName: "photo.on.rectangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 21, height: 21)
                            .foregroundColor(.blue.opacity(0.76))
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .foregroundColor(.accentColor)
                            .background(Color.white, in: Circle())
                            .frame(width: 15, height: 15)
                            .offset(x: 10, y: 10)
                            .shadow(color: .black.opacity(0.10), radius: 1, x: 1, y: 1)
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 1)
            }

            // mic button beside the camera/thumbnail
            Button { startVoiceForTask(idx) } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 13)
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .buttonStyle(.plain)

            // TASK FIELD
            TextEditor(text: Binding(
                get: { tasks[idx].title },
                set: { tasks[idx].title = $0 }
            ))
            .frame(minHeight: 38, maxHeight: 100)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(Color(.systemGray6).opacity(0.98))
            .cornerRadius(8)
            .font(.system(size: 15))
            .scrollContentBackground(.hidden)

            // REMOVE TASK
            if tasks.count > 1 {
                Button {
                    tasks.remove(at: idx)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 20, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.leading, 3)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 3)
        .background(.ultraThinMaterial)
        .cornerRadius(13)
        .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 22) {
                // PLAN DETAILS CARD
                VStack(spacing: 17) {
                    // Plan Name
                    PlanTitleField($planName)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Travel Date & Time")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $travelDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                    ReminderSection()
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.blue.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.blue.opacity(0.04), radius: 6, y: 2)
                .padding(.horizontal, 8)
                .padding(.top, 8)

                // TASKS CARD
                VStack(spacing: 13) {
                    HStack {
                        Text("Tasks")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                    }

                    ForEach(tasks.indices, id: \.self) { idx in
                        TaskRow(idx)
                    }

                    // ADD TASK BUTTON
                    Button {
                        withAnimation(.spring()) {
                            tasks.append(TravelTask(title: ""))
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Task")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.vertical, 9)
                        .padding(.horizontal, 18)
                        .background(
                            Capsule()
                                .fill(Color.accentColor.opacity(0.89))
                        )
                        .foregroundColor(.white)
                        .shadow(color: Color.accentColor.opacity(0.14), radius: 7, y: 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.blue.opacity(0.07), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 7, y: 2)
                .padding(.horizontal, 8)

                Spacer(minLength: 14)
            }
            .padding(.bottom, 18)
        }
        .navigationTitle("New Travel Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { savePlan() }
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.14))
                    )
                    .foregroundColor(.blue)
            }
        }
        .alert("Plan name is required.", isPresented: $showNameError) {
            Button("OK", role: .cancel) {}
        }
        .confirmationDialog("Attach an Image", isPresented: $showImageSourceDialog, titleVisibility: .visible) {
            Button("Take Photo") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    activeImagePickerSheet = .camera
                }
            }
            Button("Choose From Gallery") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    activeImagePickerSheet = .photoLibrary
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .onChange(of: activeImagePickerSheet) {
            if activeImagePickerSheet == nil, imageToLift != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showImageLift = true
                }
            }
        }
        .sheet(item: $activeImagePickerSheet) { source in
            FMNImagePicker(sourceType: source == .camera ? .camera : .photoLibrary) { img in
                if let img = img { imageToLift = img }
                activeImagePickerSheet = nil
            }
        }
        .sheet(isPresented: $showImageLift) {
            if let img = imageToLift, let idx = editingTaskIndex {
                ImageLiftView(uiImage: img) { subject in
                    handleLiftedImage(subject, forTaskAtIndex: idx)
                }
            }
        }
        .sheet(item: $showSubjectPreview) { subj in
            SubjectDetailView(subject: subj)
        }
        // Voice recorder for a specific task
        .sheet(isPresented: $showTaskVoiceSheet) {
            VoiceRecorderSheet(
                onFinish: { url in didFinishTaskRecording(url: url) },
                onCancel: { showTaskVoiceSheet = false },
                voiceFeatureTitle: "Add Task From Voice"
                
                // keep signature minimal; add extra params only if your sheet supports them
            )
        }
        // Transcription progress
        .sheet(isPresented: $isTaskTranscribing) {
            TranscribeProgressView()
                .interactiveDismissDisabled(true)
        }
        // Confirm transcript and commit into the task field
        .sheet(isPresented: $showConfirmTaskTranscript) {
            ConfirmTranscriptSheet(
                text: $taskTranscript,
                onUse: { acceptTaskTranscript() },
                onCancel: { showConfirmTaskTranscript = false },
                primaryLabel: "Add this task",
                primarySymbol: "plus.circle.fill"
            )
        }
        // Mic permission + error alerts
        .alert("Microphone Access Needed", isPresented: $showMicDeniedAlert) {
            Button("OK", role: .cancel) {}
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text("To record your voice, allow mic access in Settings for ForgetMeNot.")
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { voiceError != nil },
                set: { if !$0 { voiceError = nil } }
            )
        ) {
            Button("OK") { voiceError = nil }
        } message: {
            Text(voiceError ?? "")
        }
    }

    // MARK: - Save & helpers

    private func savePlan() {
        let cleanTasks = tasks.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !planName.trimmingCharacters(in: .whitespaces).isEmpty else {
            showNameError = true
            return
        }
        guard !cleanTasks.isEmpty else {
            onDone(nil)
            dismiss()
            return
        }
        let reminderOffset: TimeInterval = reminderDate.timeIntervalSince(travelDate)
        let plan = TravelPlan(name: planName, date: travelDate, tasks: cleanTasks, reminderOffset: reminderOffset)
        modelContext.insert(plan)
        NotificationHelper.scheduleTravelReminder(for: plan, offset: reminderOffset)
        onDone(plan)
    }

    private func cancel() {
        onDone(nil)
        dismiss()
    }

    private func handleLiftedImage(_ subject: UIImage, forTaskAtIndex index: Int) {
        let resized = subject.resized(maxDim: 1024)
        guard let data = resized.pngData() else { return }
        let subjImg = SubjectImage(data: data)
        modelContext.insert(subjImg)
        tasks[index].subjectImageID = subjImg.id
        showImageLift = false
        imageToLift = nil
        editingTaskIndex = nil
    }

    // MARK: - Voice-to-task helpers

    private func startVoiceForTask(_ idx: Int) {
        editingTaskIndex = idx
        Task {
            let status = await mic.request()
            if status == .granted {
                showTaskVoiceSheet = true
            } else {
                showMicDeniedAlert = true
            }
        }
    }

    private func didFinishTaskRecording(url: URL) {
        lastTaskRecordingURL = url
        showTaskVoiceSheet = false
        Task { await transcribeTask(url: url) }
    }

    private func transcribeTask(url: URL) async {
        isTaskTranscribing = true
        defer {
            isTaskTranscribing = false
            if let u = lastTaskRecordingURL {
                try? FileManager.default.removeItem(at: u)
                lastTaskRecordingURL = nil
            }
        }
        do {
            let text = try await stt.transcribe(fileURL: url)
            taskTranscript = text
            showConfirmTaskTranscript = true
        } catch {
            voiceError = error.localizedDescription
        }
    }

    private func acceptTaskTranscript() {
        if let idx = editingTaskIndex {
            let trimmed = taskTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                tasks[idx].title = trimmed
            }
        }
        taskTranscript = ""
        showConfirmTaskTranscript = false
    }
}

