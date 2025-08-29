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
    
    @State private var expandedTaskReminderIndex: Int? = nil
    // at top with other @State
    @State private var taskReminderDraft: [UUID: Date] = [:]




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
        // Robust validation with reasonable limits
        guard let n = Int(everyNumber), n > 0, n <= 1000 else {
            // Show user feedback for invalid input
            everyNumber = "1" // Reset to safe default
            return
        }
        
        let step = TimeInterval(n) * everyUnit.seconds
        
        // Additional safety: prevent steps smaller than 1 second
        guard step >= 1.0 else {
            everyNumber = "1"
            everyUnit = .minutes
            return
        }
        
        if !makeRecurring { makeRecurring = true }
        var out: [Date] = scheduledReminderDates
        var cursor = reminderDate
        let now = Date()
        
        if cursor < now {
            let delta = now.timeIntervalSince(cursor)
            let jumps = ceil(delta / step)
            cursor = cursor.addingTimeInterval(jumps * step)
        }
        
        // Add loop counter as additional safety
        var loopCounter = 0
        while cursor <= seriesUpperBound && loopCounter < 500 {
            if let ok = clampToSeriesWindow(cursor) { out.append(ok) }
            cursor = cursor.addingTimeInterval(step)
            if out.count >= 100 { break }
            loopCounter += 1
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
        // UI constants for consistency
        let iconSide: CGFloat = 36
        let iconCorner: CGFloat = 8
        let sepHeight: CGFloat = 28
        let controlH: CGFloat = 36

        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 4) {    // tighter spacing
                // SUBJECT IMAGE THUMBNAIL or camera placeholder
                if let id = tasks[idx].subjectImageID,
                   let subj = subjects.first(where: { $0.id == id }),
                   let thumb = subj.thumbnail {
                    Button { showSubjectPreview = subj } label: {
                        Image(uiImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: iconSide, height: iconSide)
                            .clipShape(RoundedRectangle(cornerRadius: iconCorner, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: iconCorner)
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Add Image (more rectangular)
                    Button {
                        editingTaskIndex = idx
                        showImageSourceDialog = true
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: iconCorner)
                                .fill(Color(.systemGray5))
                                .frame(width: iconSide, height: iconSide)
                            Image(systemName: "photo.on.rectangle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .foregroundColor(.blue.opacity(0.76))
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .foregroundColor(.accentColor)
                                .background(Color.white, in: Circle())
                                .frame(width: 14, height: 14)
                                .offset(x: 10, y: 10)
                                .shadow(color: .black.opacity(0.10), radius: 1, x: 1, y: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }

                // vertical separator
                Rectangle().fill(Color.secondary.opacity(0.15))
                    .frame(width: 1, height: sepHeight)

                // Mic (packed)
                Button { startVoiceForTask(idx) } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: iconCorner)
                            .fill(Color(.systemGray5))
                            .frame(width: iconSide, height: iconSide)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                }
                .buttonStyle(.plain)

                // vertical separator
                Rectangle().fill(Color.secondary.opacity(0.15))
                    .frame(width: 1, height: sepHeight)

                // Reminder (more rectangular; stateful plus/check)
                Button {
                    withAnimation(.spring()) {
                        if expandedTaskReminderIndex == idx {
                            expandedTaskReminderIndex = nil
                        } else {
                            expandedTaskReminderIndex = idx
                            let tid = tasks[idx].id
                            if taskReminderDraft[tid] == nil {
                                taskReminderDraft[tid] = tasks[idx].reminderAt ?? Date().addingTimeInterval(3600)
                            }
                        }
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: iconCorner)
                            .fill(Color(.systemGray5))
                            .frame(width: iconSide, height: iconSide)

                        Image(systemName: "bell")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .foregroundColor(.accentColor)

                        let hasReminder = tasks[idx].reminderAt != nil
                        Image(systemName: hasReminder ? "checkmark.circle.fill" : "plus.circle.fill")
                            .resizable()
                            .foregroundColor(hasReminder ? .green : .accentColor)
                            .background(Color.white, in: Circle())
                            .frame(width: 14, height: 14)
                            .offset(x: 9, y: 9)
                            .shadow(color: .black.opacity(0.10), radius: 1, x: 1, y: 1)
                    }
                }
                .buttonStyle(.plain)

                // TASK FIELD (now gets more width)
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
                    .padding(.leading, 2)
                }
            }

            // Saved reminder chip when collapsed
            if expandedTaskReminderIndex != idx, let saved = tasks[idx].reminderAt {
                HStack(spacing: 6) {
                    Image(systemName: "bell.fill").foregroundColor(.accentColor)
                    Text(saved.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.top, 2)
                .transition(.opacity)
            }

            // Expander
            if expandedTaskReminderIndex == idx {
                HStack(spacing: 8) {
                    let tid = tasks[idx].id
                    let draftBinding = Binding<Date>(
                        get: { taskReminderDraft[tid] ?? tasks[idx].reminderAt ?? Date().addingTimeInterval(3600) },
                        set: { taskReminderDraft[tid] = $0 }
                    )

                    // Match control heights
                    DatePicker(
                        "",
                        selection: draftBinding,
                        in: customPickerSafeRange,                // safer range
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(height: controlH)

                    // Saved state (within 0.5s)
                    let isSaved: Bool = {
                        guard let d = taskReminderDraft[tid], let r = tasks[idx].reminderAt else { return false }
                        return abs(d.timeIntervalSinceReferenceDate - r.timeIntervalSinceReferenceDate) < 0.5
                    }()

                    // Commit (icon the same height as DatePicker)
                    Button {
                        let picked = taskReminderDraft[tid] ?? Date().addingTimeInterval(3600)
                        tasks[idx].reminderAt = picked
                        withAnimation(.spring()) { expandedTaskReminderIndex = nil }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: iconCorner)
                                .fill(Color(.systemGray5))
                            Image(systemName: isSaved ? "checkmark" : "bell.badge")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(isSaved ? .green : .accentColor)
                        }
                    }
                    .frame(width: controlH, height: controlH)
                    .buttonStyle(.plain)

                    // Trash (icon same height as DatePicker)
                    Button {
                        tasks[idx].reminderAt = nil
                        taskReminderDraft[tid] = nil
                        if expandedTaskReminderIndex == idx { expandedTaskReminderIndex = nil }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: iconCorner)
                                .fill(Color(.systemGray5))
                            Image(systemName: "trash")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.red)
                        }
                    }
                    .frame(width: controlH, height: controlH)
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        // 2) Border around each task row
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
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
        
        .onAppear {
            expandedTaskReminderIndex = nil
        }
        .onChange(of: tasks.count) { _ in
            expandedTaskReminderIndex = nil
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
            
            for i in tasks.indices {
                if let d = tasks[i].reminderAt, d > eventDate {
                    tasks[i].reminderAt = eventDate
                }
            }


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
        let offsets = Array(offsetsAll.prefix(64))
        let plan = EventPlan(
            name: planName,
            date: eventDate,
            tasks: cleanTasks,
            reminderOffset: offsets.first ?? 0,   // was -3600
            reminderOffsets: offsets
        )

        modelContext.insert(plan)

        // Schedule Event Reminders
        NotificationHelper.scheduleEventReminders(for: plan, offsets: offsets)
        
        // NewEventPlanView.savePlan()
        for task in plan.tasks where task.reminderAt != nil {
            NotificationHelper.scheduleTaskReminder(for: plan, task: task)
        }

        

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

