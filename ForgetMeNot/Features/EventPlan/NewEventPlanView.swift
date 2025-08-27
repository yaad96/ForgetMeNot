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

struct NewEventPlanView: View {
    init(
        planName: String = "",
        eventDate: Date = .now.addingTimeInterval(86400),
        reminderDate: Date = .now.addingTimeInterval(43200),
        tasks: [EventTask] = [EventTask(title: "Collect keys"), EventTask(title: "Pack passport")],
        onDone: @escaping (EventPlan?) -> Void
    ) {
        self.onDone = onDone
        _planName = State(initialValue: planName)
        _eventDate = State(initialValue: eventDate)
        _reminderDate = State(initialValue: reminderDate)
        _tasks = State(initialValue: tasks)
        _customReminderInstant = State(initialValue: reminderDate)
        _recurringReminderEndDate = State(initialValue: eventDate)

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
    @State private var eventDate: Date = .now.addingTimeInterval(86400)
    @State private var reminderDate: Date = .now.addingTimeInterval(43200)
    @State private var tasks: [EventTask] = [
        EventTask(title: "Collect keys"),
        EventTask(title: "Pack passport")
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

    var onDone: (EventPlan?) -> Void

    // =========================
    // Recurring reminder states
    // =========================
    enum IntervalUnit: String, CaseIterable, Identifiable {
        case seconds, minutes, hours
        var id: Self { self }
        var seconds: TimeInterval {
            switch self {
            case .seconds: return 1
            case .minutes: return 60
            case .hours:   return 3600
            }
        }
        var label: String { switch self { case .seconds: return "sec"; case .minutes: return "min"; case .hours: return "hr" } }
    }

    @State private var makeRecurring: Bool = false
    @State private var scheduledReminderDates: [Date] = []     // preview list for “Will Schedule”
    @State private var everyNumber: String = "1"
    @State private var everyUnit: IntervalUnit = .hours

    @State private var customReminderInstant: Date = .now      // date+time picker for single add
    // End date for the recurring series, defaults to eventDate
    @State private var recurringReminderEndDate: Date = .now.addingTimeInterval(86400)

    // Treat reminderDate as the series start for clarity
    private var recurringReminderStartDate: Date { reminderDate }

    /// Upper bound for the recurring series (custom reminders ignore this and use eventDate)
    private var seriesUpperBound: Date { min(eventDate, recurringReminderEndDate) }


    // MARK: - Small helpers

    // Only for the recurring series
    private func clampToSeriesWindow(_ date: Date) -> Date? {
        let now = Date()
        if date < now { return nil }
        if date > seriesUpperBound { return nil }   // <= min(eventDate, recurringEnd)
        return date
    }

    // For custom one-off reminders (independent of recurring end)
    private func clampToEventWindow(_ date: Date) -> Date? {
        let now = Date()
        if date < now { return nil }
        if date > eventDate { return nil }          // <= eventDate only
        return date
    }



    private func addIntervalSeries() {
        guard let n = Int(everyNumber), n > 0 else { return }
        let step = TimeInterval(n) * everyUnit.seconds
        if !makeRecurring { makeRecurring = true }

        var out: [Date] = scheduledReminderDates
        var cursor = reminderDate
        let now = Date()
        if cursor < now {
            let delta = now.timeIntervalSince(cursor)
            let jumps = ceil(delta / step)
            cursor = cursor.addingTimeInterval(jumps * step)
        }
        while cursor <= seriesUpperBound {
            if let ok = clampToSeriesWindow(cursor) { out.append(ok) }
            cursor = cursor.addingTimeInterval(step)
            if out.count >= 100 { break }
        }


        scheduledReminderDates = normalizedUpcoming(out)
    }


    private func addCustomInstant() {
        if let ok = clampToEventWindow(customReminderInstant) {
            if !makeRecurring { makeRecurring = true }
            var out = scheduledReminderDates
            if out.isEmpty, let base = clampToEventWindow(reminderDate) {
                out.append(base)
            }
            out.append(ok)
            scheduledReminderDates = normalizedUpcoming(out)
        }
    }




    private func removeInstant(_ date: Date) {
        scheduledReminderDates.removeAll { abs($0.timeIntervalSince1970 - date.timeIntervalSince1970) < 0.5 }
    }
    
    // 1) Add this helper somewhere in the view (e.g., near other helpers)
    private var customPickerSafeRange: ClosedRange<Date> {
        let now = Date()
        return eventDate >= now ? now...eventDate : now...now
    }


    
    // Keep the list clean, future-only, within event window, unique, sorted, and capped to 100
    private func normalizedUpcoming(_ dates: [Date]) -> [Date] {
        let now = Date()
        let uniqKeys = Set(dates.map { $0.timeIntervalSinceReferenceDate })
        let uniqDates = uniqKeys.map { Date(timeIntervalSinceReferenceDate: $0) }

        let filtered = uniqDates.filter { $0 >= now && $0 <= eventDate } // <- eventDate
        let sorted = filtered.sorted()
        return Array(sorted.prefix(100))
    }


    
    private var reminderDateLine: String {
        """
        Start at reminder date: \(recurringReminderStartDate.formatted(date: .abbreviated, time: .shortened))
        Repeats until: \(recurringReminderEndDate.formatted(date: .abbreviated, time: .shortened))
        """
    }

    // --- Small helper to keep ForEach closures tiny
    @ViewBuilder
    private func ReminderSection() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $makeRecurring) {
                Label("Add Reminders", systemImage: "arrow.triangle.2.circlepath")
            }
            .padding(.top, 6)

            if makeRecurring {
                RecurringControls()
            }
        }
    }


    @ViewBuilder
    private func RecurringControls() -> some View {
        VStack(alignment: .leading, spacing: 12) {

            // Top title
            Text("Reminders")
                .font(.headline)

            Divider().padding(.vertical, 2)

            // Recurring
            Text("Recurring Reminders")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)

            // Start
            Text("Reminder Start Date")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)

            DatePicker(
                "",
                selection: $reminderDate,
                in: ...recurringReminderEndDate,    // keep start <= end
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)

            // Interval builder
            VStack(alignment: .leading, spacing: 8) {
                Text("Remind me after every")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    TextField("Number", text: $everyNumber)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)

                    Picker("", selection: $everyUnit) {
                        ForEach(IntervalUnit.allCases) { u in
                            Text(u.label).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text(reminderDateLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // End
            Text("Reminder End Date")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)

            DatePicker(
                "",
                selection: $recurringReminderEndDate,
                in: recurringReminderStartDate...eventDate,   // keep end within event
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)

            // Big action button
            Button {
                addIntervalSeries()
            } label: {
                Label("Set Reminder Series", systemImage: "calendar.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 6)

            Divider().padding(.vertical, 2)

            // Custom reminder adding UI
            VStack(alignment: .leading, spacing: 6) {
                Text("Or add a custom date & time")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    DatePicker(
                        "",
                        selection: $customReminderInstant,
                        in: customPickerSafeRange,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)

                    Button { addCustomInstant() } label: {
                        Label("Add Time", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(customPickerSafeRange.lowerBound == customPickerSafeRange.upperBound)
                }

                if customPickerSafeRange.lowerBound == customPickerSafeRange.upperBound {
                    Text("Event date is in the past. Move the event to a future time to add reminders.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // Preview
            if !scheduledReminderDates.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Will Schedule")
                        .font(.footnote.weight(.semibold))
                        .foregroundColor(.secondary)

                    ForEach(scheduledReminderDates, id: \.timeIntervalSinceReferenceDate) { d in
                        HStack(spacing: 8) {
                            Image(systemName: "bell")
                                .foregroundColor(.accentColor)
                            Text(d.formatted(date: .abbreviated, time: .shortened))
                                .font(.callout)
                            Spacer()
                            Button {
                                removeInstant(d)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
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
                VStack(alignment:.leading, spacing: 17) {
                    // Plan Name
                    PlanTitleField($planName)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Event Date & Time")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
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
                            tasks.append(EventTask(title: ""))
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
        .navigationTitle("New Event Plan")
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
        .onChange(of: eventDate) { _ in
            // keep end <= event
            if recurringReminderEndDate > eventDate { recurringReminderEndDate = eventDate }

            // keep custom picker within safe range
            let r = customPickerSafeRange
            if customReminderInstant < r.lowerBound { customReminderInstant = r.lowerBound }
            if customReminderInstant > r.upperBound { customReminderInstant = r.upperBound }

            // keep single reminder date <= event date
            if reminderDate > eventDate { reminderDate = eventDate }

            // re-normalize preview list under new bounds
            scheduledReminderDates = normalizedUpcoming(scheduledReminderDates)
        }
        
        // If start moves past end, push end up to start. Then re-normalize.
        .onChange(of: reminderDate) { newStart in
            if recurringReminderEndDate < newStart {
                recurringReminderEndDate = newStart
            }
            scheduledReminderDates = normalizedUpcoming(scheduledReminderDates)
        }

        // If end moves earlier, clamp custom picker and re-normalize
        .onChange(of: recurringReminderEndDate) { _ in
            let r = customPickerSafeRange
            if customReminderInstant > r.upperBound { customReminderInstant = r.upperBound }
            scheduledReminderDates = normalizedUpcoming(scheduledReminderDates)
        }



        .onChange(of: makeRecurring) { on in
            if on {
                if scheduledReminderDates.isEmpty,
                   let base = clampToEventWindow(reminderDate) {
                    scheduledReminderDates = [base]
                }
            } else {
                scheduledReminderDates.removeAll()
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

        // --- Build the dates to schedule ---
        let dates0 = normalizedUpcoming(scheduledReminderDates)

        let dates: [Date]
        if makeRecurring {
            if dates0.isEmpty {
                if let base = clampToEventWindow(reminderDate) {
                    dates = [base]
                } else {
                    dates = []
                }
            } else {
                dates = dates0
            }
        } else {
            if let base = clampToEventWindow(reminderDate) {
                dates = [base]
            } else {
                dates = []
            }
        }

        let offsetsAll = dates.map { $0.timeIntervalSince(eventDate) }.sorted()
        let offsets = Array(offsetsAll.prefix(64)) // optional safety cap

        // Create and persist the plan
        let plan = EventPlan(
            name: planName,
            date: eventDate,
            tasks: cleanTasks,
            reminderOffset: offsets.first ?? -3600, // legacy field fallback
            reminderOffsets: offsets
        )
        modelContext.insert(plan)

        // Schedule
        NotificationHelper.scheduleEventReminders(for: plan, offsets: offsets)

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

