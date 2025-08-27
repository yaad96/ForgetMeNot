import SwiftUI
import SwiftData
import UIKit

struct EventPlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: EventPlan

    @Query var subjects: [SubjectImage]

    // --- Local Editing State ---
    @State private var isEditing = false
    @State private var planName: String = ""
    @State private var eventDate: Date = .now
    @State private var reminderDate: Date = .now
    @State private var tasks: [EventTask] = []

    // Recurring reminder UI state (editing)
    enum IntervalUnit: String, CaseIterable, Identifiable { case seconds, minutes, hours
        var id: Self { self }
        var seconds: TimeInterval { self == .seconds ? 1 : (self == .minutes ? 60 : 3600) }
        var label: String {switch self { case .seconds: return "sec"; case .minutes: return "min"; case .hours: return "hr" }}
    }
    @State private var makeRecurring: Bool = false
    @State private var scheduledReminderDates: [Date] = []   // read-only list you display elsewhere
    @State private var everyNumber: String = "1"
    @State private var everyUnit: IntervalUnit = .hours
    @State private var customReminderInstant: Date = .now
    @State private var showAllReminders = false


    // --- Image Picker Logic ---
    @State private var showImageSourceDialog = false
    @State private var activeImagePickerSheet: ImagePickerSheet?
    @State private var imageToLift: UIImage?
    @State private var editingTaskIndex: Int?
    @State private var showImageLift = false
    @State private var showSubjectPreview: SubjectImage?
    @State private var pendingImageToLift: UIImage? = nil

    // --- UI & Alerts ---
    @State private var showNameError = false
    @State private var showSaveAlert = false
    @State private var showCompletedAlert = false

    // --- Voice-to-Task (editing) ---
    @State private var showTaskVoiceSheet = false
    @State private var isTaskTranscribing = false
    @State private var showConfirmTaskTranscript = false
    @State private var taskTranscript: String = ""
    @State private var lastTaskRecordingURL: URL?
    @State private var showMicDeniedAlert = false
    @State private var voiceError: String?

    private let mic = MicPermissionService()
    private let stt = OpenAITranscriptionService(apiKey: APIKeyLoader.openAIKey)
    
    // End date for recurring series (defaults to eventDate in initializeEditFields)
    @State private var recurringReminderEndDate: Date = .now

    private var recurringReminderStartDate: Date { reminderDate }
    private var seriesUpperBound: Date { min(eventDate, recurringReminderEndDate) }

    private var reminderDateLine: String {
        """
        Start at reminder date: \(recurringReminderStartDate.formatted(date: .abbreviated, time: .shortened))
        Repeats until: \(recurringReminderEndDate.formatted(date: .abbreviated, time: .shortened))
        """
    }


    // MARK: - Helpers

    // Recurring series window (bounded by seriesUpperBound = min(eventDate, recurringEnd))
    private func clampToSeriesWindow(_ date: Date) -> Date? {
        let now = Date()
        if date < now { return nil }
        if date > seriesUpperBound { return nil }
        return date
    }

    // Custom one-off reminders (bounded only by eventDate)
    private func clampToEventWindow(_ date: Date) -> Date? {
        let now = Date()
        if date < now { return nil }
        if date > eventDate { return nil }
        return date
    }

    // Custom picker range: from now up to eventDate (independent of recurring end)
    private var customPickerSafeRange: ClosedRange<Date> {
        let now = Date()
        return eventDate >= now ? now...eventDate : now...now
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
            if !makeRecurring { makeRecurring = true }   // keep your UX
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
    
    // Keep the list clean, future-only, within event window, unique, sorted, and capped to 100
    private func normalizedUpcoming(_ dates: [Date]) -> [Date] {
        let now = Date()
        let uniqKeys = Set(dates.map { $0.timeIntervalSinceReferenceDate })
        let uniqDates = uniqKeys.map { Date(timeIntervalSinceReferenceDate: $0) }
        let filtered = uniqDates.filter { $0 >= now && $0 <= eventDate }
        let sorted = filtered.sorted()
        return Array(sorted.prefix(100))
    }

    
    private func prunePersistedPastRemindersIfNeeded() {
        let now = Date()
        let pruned = plan.allReminderOffsets
            .filter { plan.date.addingTimeInterval($0) >= now }
            .sorted()
        // Cap to 100 just to be consistent everywhere
        let capped = Array(pruned.prefix(100))
        if capped != plan.reminderOffsets {
            plan.reminderOffsets = capped
            NotificationHelper.cancelReminder(for: plan)
            NotificationHelper.scheduleEventReminders(for: plan, offsets: capped)
        }
    }




    // MARK: - Tiny helpers to keep the type checker happy

    @ViewBuilder
    private func EventDateEditingSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Event Date & Time")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            DatePicker(
                "",
                selection: $eventDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
    }

    @ViewBuilder
    private func EventDateDisplaySection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Event Date & Time")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            let d = plan.date
            Text(d.formatted(date: .long, time: .shortened))
                .font(.callout)
                .foregroundColor(.primary)
        }
    }

    @ViewBuilder
    private func ReminderEditingSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reminder")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            Toggle(isOn: $makeRecurring) {
                Label("Add More Reminders", systemImage: "arrow.triangle.2.circlepath")
            }
            .padding(.top, 6)

            if makeRecurring {
                RecurringControls()   // the only place with start/end pickers
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
                in: ...recurringReminderEndDate,            // start <= end
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
                in: recurringReminderStartDate...eventDate, // end within event; end >= start
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

            // Custom reminders (independent of recurring end)
            VStack(alignment: .leading, spacing: 6) {
                Text("Or add a custom date & time")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    DatePicker(
                        "",
                        selection: $customReminderInstant,
                        in: customPickerSafeRange,                 // now...eventDate
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
                            Button { removeInstant(d) } label: {
                                Image(systemName: "minus.circle.fill").foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
    }


    @ViewBuilder
    private func ReminderDisplaySection() -> some View {
        let all = plan.allReminderOffsets.map { plan.date.addingTimeInterval($0) }.sorted()
        let now = Date()
        let upcoming = all.filter { $0 >= now }
        let next = upcoming.first

        VStack(alignment: .leading, spacing: 8) {
            Text("Reminders")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)

            if upcoming.isEmpty {
                Text("—").foregroundColor(.secondary)
            } else {
                if let next = next {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill").foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Next reminder").font(.subheadline).foregroundColor(.secondary)
                            Text(next.formatted(date: .abbreviated, time: .shortened)).font(.callout)
                            Text(next, style: .relative).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                let chunk = Array(upcoming.prefix(5))
                VStack(alignment: .leading, spacing: 6) {
                    Text("Next \(chunk.count) reminder\(chunk.count == 1 ? "" : "s")")
                        .font(.caption).foregroundColor(.secondary)
                    ForEach(chunk, id: \.timeIntervalSinceReferenceDate) { d in
                        HStack(spacing: 8) {
                            Image(systemName: "clock").foregroundColor(.accentColor)
                            Text(d.formatted(date: .abbreviated, time: .shortened)).font(.callout)
                            Spacer()
                            Text(d, style: .relative).font(.caption2).foregroundColor(.secondary)
                        }
                    }
                    if upcoming.count > chunk.count {
                        Text("+\(upcoming.count - chunk.count) more scheduled")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
    }



    
    @ViewBuilder
    private func EventDateSectionSwitcher() -> some View {
        if isEditing {
            EventDateEditingSection()
        } else {
            EventDateDisplaySection()
        }
    }

    @ViewBuilder
    private func ReminderSectionSwitcher() -> some View {
        if isEditing {
            ReminderEditingSection()   // no `upper:` argument anymore
        } else {
            ReminderDisplaySection()
        }
    }


    // MARK: - Body

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // PLAN DETAILS CARD
                VStack(alignment:.leading, spacing: 15) {
                    if isEditing {
                        PlanTitleField($planName)
                    } else {
                        let name = plan.name
                        Text(name)
                            .font(.system(size: 22, weight: .bold))
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    EventDateSectionSwitcher()
                    ReminderSectionSwitcher()
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.blue.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
                .padding(.horizontal, 7)
                .padding(.top, 8)

                // TASKS CARD
                VStack(spacing: 11) {
                    HStack {
                        Text("Tasks")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        Spacer()
                    }

                    if isEditing {
                        ForEach(tasks.indices, id: \.self) { idx in
                            taskRow(idx: idx, editing: true)
                        }
                        Button {
                            withAnimation(.spring()) {
                                tasks.append(EventTask(title: ""))
                            }
                        } label: {
                            Label("Add Task", systemImage: "plus.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.90))
                                )
                                .foregroundColor(.white)
                                .shadow(color: Color.accentColor.opacity(0.11), radius: 4, y: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 3)
                    } else {
                        ForEach(plan.tasks.indices, id: \.self) { idx in
                            taskRow(idx: idx, editing: false)
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.blue.opacity(0.07), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.03), radius: 5, y: 1)
                .padding(.horizontal, 7)

                // "I'm All Set" Button
                if !isEditing && plan.tasks.count > 0 && plan.tasks.allSatisfy({ $0.isCompleted }) && !plan.isCompleted {
                    Button {
                        plan.isCompleted = true
                        NotificationHelper.cancelReminder(for: plan)
                        showCompletedAlert = true
                    } label: {
                        Text("I'm All Set")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(Color.green)
                            )
                            .shadow(color: .green.opacity(0.08), radius: 3, y: 2)
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 8)
                } else if !isEditing && plan.tasks.count > 0 && plan.tasks.allSatisfy({ $0.isCompleted }) && plan.isCompleted {
                    Button {} label: {
                        Text("All Tasks Completed")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule()
                                    .fill(Color.gray.opacity(0.70))
                            )
                            .padding(.horizontal, 20)
                    }
                    .disabled(true)
                    .padding(.top, 8)
                }

                Spacer(minLength: 14)
            }
            .padding(.bottom, 18)
        }
        .navigationTitle("Plan Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !plan.isCompleted && isEditing {
                    Button {
                        cancelEdits()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.red)
                    }
                    Button {
                        saveEdits()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.green)
                    }
                } else if !plan.isCompleted && !isEditing {
                    Button {
                        enterEditMode()
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .alert("Plan name is required.", isPresented: $showNameError) {
            Button("OK", role: .cancel) {}
        }
        .alert("Changes Saved!", isPresented: $showSaveAlert) {
            Button("OK") { showSaveAlert = false }
        }
        .alert("All Tasks Completed, Congrats!", isPresented: $showCompletedAlert) {
            Button("OK") { dismiss() }
        }
        .confirmationDialog(
            "Attach an Image",
            isPresented: $showImageSourceDialog,
            titleVisibility: .visible
        ) {
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
        .sheet(item: $activeImagePickerSheet) { source in
            FMNImagePicker(sourceType: source == .camera ? .camera : .photoLibrary) { img in
                if let img = img {
                    pendingImageToLift = img
                }
                activeImagePickerSheet = nil
            }
        }
        .onChange(of: pendingImageToLift) { newImg in
            if let img = newImg {
                imageToLift = img
                showImageLift = true
                pendingImageToLift = nil
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

            scheduledReminderDates = normalizedUpcoming(scheduledReminderDates)
        }
        
        .onChange(of: reminderDate) { newStart in
            if recurringReminderEndDate < newStart {
                recurringReminderEndDate = newStart
            }
            scheduledReminderDates = normalizedUpcoming(scheduledReminderDates)
        }
        
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
        .onAppear {
            initializeEditFields()
            prunePersistedPastRemindersIfNeeded()
        }

        // Voice recorder (task)
        .sheet(isPresented: $showTaskVoiceSheet) {
            VoiceRecorderSheet(
                onFinish: { url in didFinishTaskRecording(url: url) },
                onCancel: { didCancelTaskRecording() },
                voiceFeatureTitle: "Add Task from Voice"
            )
        }
        // Transcribing progress (task)
        .sheet(isPresented: $isTaskTranscribing) {
            TranscribeProgressView()
                .interactiveDismissDisabled(true)
        }
        // Confirm/edit transcript -> Add this task
        .sheet(isPresented: $showConfirmTaskTranscript) {
            ConfirmTranscriptSheet(
                text: $taskTranscript,
                onUse: { acceptTaskTranscript() },
                onCancel: { showConfirmTaskTranscript = false },
                primaryLabel: "Add this task",
                primarySymbol: "plus.circle.fill"
            )
        }
        // Mic denied
        .alert("Microphone Access Needed", isPresented: $showMicDeniedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("To record your voice, allow mic access in Settings for ForgetMeNot.")
        }
        // Voice errors (if any)
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

    // MARK: - Task Row
    @ViewBuilder
    func taskRow(idx: Int, editing: Bool) -> some View {
        let task = editing ? tasks[idx] : plan.tasks[idx]
        HStack(alignment: .center, spacing: 10) {
            Button {
                if editing {
                    tasks[idx].isCompleted.toggle()
                } else if !plan.isCompleted {
                    plan.tasks[idx].isCompleted.toggle()
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Group {
                if editing {
                    TextField(
                        "What to do?",
                        text: Binding(
                            get: { tasks[idx].title },
                            set: { tasks[idx].title = $0 }
                        )
                    )
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color(.systemGray6).opacity(0.97))
                    .cornerRadius(8)
                    .font(.system(size: 15, weight: .regular))
                } else {
                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .font(.system(size: 15, weight: .regular))
                        .padding(.vertical, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let id = task.subjectImageID,
               let subj = subjects.first(where: { $0.id == id }),
               let thumb = subj.thumbnail {
                Button {
                    if editing {
                        editingTaskIndex = idx
                        showImageSourceDialog = true
                    } else {
                        showSubjectPreview = subj
                    }
                } label: {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 38, height: 38)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.white.opacity(0.8), lineWidth: 1.1)
                        )
                        .shadow(color: Color.black.opacity(0.07), radius: 5, y: 1)
                        .padding(.trailing, 1)
                }
                .buttonStyle(.plain)
            } else if editing {
                Button {
                    editingTaskIndex = idx
                    showImageSourceDialog = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(width: 38, height: 38)
                        Image(systemName: "photo.on.rectangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 15, height: 15)
                            .foregroundColor(.blue.opacity(0.75))
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .foregroundColor(.accentColor)
                            .background(Color.white, in: Circle())
                            .frame(width: 13, height: 13)
                            .offset(x: 8, y: 8)
                            .shadow(color: .black.opacity(0.10), radius: 1, x: 1, y: 1)
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 1)
            }

            if editing {
                Button {
                    editingTaskIndex = idx
                    onTapTaskVoice()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(width: 38, height: 38)
                        Image(systemName: "mic.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 18)
                            .foregroundColor(.accentColor)
                    }
                }
                .buttonStyle(.plain)
            }

            if editing && tasks.count > 1 {
                Button {
                    tasks.remove(at: idx)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 19, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.leading, 3)
            }
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.02), radius: 2, y: 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Editing Logic

    private func initializeEditFields() {
        planName = plan.name
        eventDate = plan.date

        let allDates = plan.allReminderOffsets.map { plan.date.addingTimeInterval($0) }.sorted()
        reminderDate = allDates.first ?? plan.date.addingTimeInterval(plan.reminderOffset)

        scheduledReminderDates = allDates
        makeRecurring = scheduledReminderDates.count > 1

        // NEW: default recurring end date to the event date (matches NewEventPlanView)
        recurringReminderEndDate = eventDate

        tasks = plan.tasks
        customReminderInstant = reminderDate
    }


    private func enterEditMode() {
        initializeEditFields()
        isEditing = true
    }

    private func saveEdits() {
        let cleanTasks = tasks.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !planName.trimmingCharacters(in: .whitespaces).isEmpty else {
            showNameError = true
            return
        }
        guard !cleanTasks.isEmpty else {
            isEditing = false
            return
        }

        // Persist core fields
        plan.name = planName
        plan.date = eventDate
        plan.tasks = cleanTasks

        // --- Build the dates to schedule ---
        // 1) Normalize any previewed dates to [now ... eventDate]
        let dates0 = normalizedUpcoming(scheduledReminderDates)

        // 2) Decide what to use, with bulletproof seeding
        let dates: [Date]
        if makeRecurring {
            if dates0.isEmpty {
                // Seed one base reminder if it's still valid
                if let base = clampToEventWindow(reminderDate) {
                    dates = [base]
                } else {
                    dates = []
                }
            } else {
                dates = dates0
            }
        } else {
            // Single reminder mode
            if let base = clampToEventWindow(reminderDate) {
                dates = [base]
            } else {
                dates = []
            }
        }

        // 3) Convert to offsets relative to eventDate (negative = before event)
        let offsetsAll = dates.map { $0.timeIntervalSince(eventDate) }.sorted()

        // 4) (Optional) Trim to a safe cap for iOS pending notifications
        let offsets = Array(offsetsAll.prefix(64))

        // Persist legacy + multi
        plan.reminderOffset  = offsets.first ?? plan.reminderOffset
        plan.reminderOffsets = offsets

        // Reschedule
        NotificationHelper.cancelReminder(for: plan)
        NotificationHelper.scheduleEventReminders(for: plan, offsets: offsets)

        isEditing = false
        // showSaveAlert = true
    }


    private func cancelEdits() {
        isEditing = false
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

    // MARK: - Voice-to-Task helpers

    private func onTapTaskVoice() {
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

    private func didCancelTaskRecording() {
        showTaskVoiceSheet = false
        editingTaskIndex = nil
    }

    private func transcribeTask(url: URL) async {
        isTaskTranscribing = true
        defer {
            isTaskTranscribing = false
            if let url = lastTaskRecordingURL {
                try? FileManager.default.removeItem(at: url)
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
        guard let idx = editingTaskIndex else { return }
        tasks[idx].title = taskTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        showConfirmTaskTranscript = false
        taskTranscript = ""
        editingTaskIndex = nil
    }
}

