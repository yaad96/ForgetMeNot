import SwiftUI
import SwiftData
import UIKit

struct TravelPlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var plan: TravelPlan
    @Query var subjects: [SubjectImage]
    @State private var selectedSubject: SubjectImage?
    @State private var isEditing = false
    @State private var showSaveAlert = false
    @State private var showCompletedAlert = false

    @State private var tempTravelDate: Date
    @State private var tempNotificationOffset: TimeInterval

    // Image editing states
    @State private var editingTaskIndex: Int? = nil
    @State private var showImageSource = false
    @State private var imageSource: UIImagePickerController.SourceType?
    @State private var showImagePicker = false
    @State private var imageToLift: UIImage?
    @State private var showImageLift = false

    init(plan: TravelPlan) {
        self._plan = Bindable(wrappedValue: plan)
        _tempTravelDate = State(initialValue: plan.date)
        _tempNotificationOffset = State(initialValue: plan.reminderOffset)
    }

    var editableNotificationDate: Date {
        get { tempTravelDate.addingTimeInterval(tempNotificationOffset) }
        set { tempNotificationOffset = newValue.timeIntervalSince(tempTravelDate) }
    }

    var allDone: Bool {
        plan.tasks.count > 0 && plan.tasks.allSatisfy { $0.isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(plan.name)
                .font(.largeTitle.bold())
                .padding(.top)

            // Travel Date
            VStack(alignment: .leading, spacing: 4) {
                Text("Travel Date:")
                    .font(.headline)
                DatePicker("Travel Date", selection: $tempTravelDate, displayedComponents: [.date, .hourAndMinute])
                    .disabled(!(isEditing && !plan.isCompleted))
                    .labelsHidden()
            }
            .padding(.top, 2)
            .padding(.horizontal)

            // Notification Date
            VStack(alignment: .leading, spacing: 4) {
                Text("Notification:")
                    .font(.headline)
                DatePicker(
                    "Notification",
                    selection: Binding(
                        get: { editableNotificationDate },
                        set: { editableNotificationDate in
                            tempNotificationOffset = editableNotificationDate.timeIntervalSince(tempTravelDate)
                        }
                    ),
                    in: ...tempTravelDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .disabled(!(isEditing && !plan.isCompleted))
                .labelsHidden()
            }
            .padding(.bottom, 8)
            .padding(.horizontal)

            // ---- SINGLE DYNAMIC EDIT/SAVE BUTTON ----
            if !plan.isCompleted {
                Button {
                    if !isEditing {
                        // Enter edit mode, copy temp fields
                        tempTravelDate = plan.date
                        tempNotificationOffset = plan.reminderOffset
                        isEditing = true
                    } else {
                        // Save changes and exit edit mode
                        plan.date = tempTravelDate
                        plan.reminderOffset = tempNotificationOffset
                        NotificationHelper.cancelReminder(for: plan)
                        NotificationHelper.scheduleTravelReminder(for: plan, offset: plan.reminderOffset)
                        isEditing = false
                        showSaveAlert = true
                    }
                } label: {
                    Text(isEditing ? "Save Changes" : "Edit Tasks")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isEditing ? Color.blue : Color.green)
                        .cornerRadius(12)
                        .shadow(radius: 3)
                        .padding(.horizontal)
                        .padding(.top, 10)
                }
            }

            // Tasks Section
            List {
                Section("Tasks") {
                    ForEach(Array(plan.tasks.enumerated()), id: \.element.id) { idx, _ in
                        HStack(alignment: .center, spacing: 16) {
                            // Checkbox
                            Button {
                                guard !plan.isCompleted else { return }
                                plan.tasks[idx].isCompleted.toggle()
                            } label: {
                                Image(systemName: plan.tasks[idx].isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(plan.tasks[idx].isCompleted ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            // Title
                            TextField("Task", text: $plan.tasks[idx].title)
                                .disabled(!(isEditing && !plan.isCompleted))
                                .strikethrough(plan.tasks[idx].isCompleted)
                                .foregroundColor(plan.tasks[idx].isCompleted ? .secondary : .primary)
                                .font(.system(size: 18, weight: .regular))
                                .padding(.vertical, 10)

                            Spacer()

                            // Image logic (rounded rect thumbnail)
                            if let id = plan.tasks[idx].subjectImageID,
                               let subj = subjects.first(where: { $0.id == id }),
                               let thumb = subj.thumbnail {
                                Button {
                                    if isEditing && !plan.isCompleted {
                                        editingTaskIndex = idx // use correct idx
                                        showImageSource = true
                                    } else {
                                        selectedSubject = subj
                                    }
                                } label: {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if isEditing && !plan.isCompleted {
                                        Button(role: .destructive) {
                                            plan.tasks[idx].subjectImageID = nil
                                        } label: {
                                            Label("Remove Image", systemImage: "trash")
                                        }
                                    }
                                }
                            } else if isEditing && !plan.isCompleted {
                                Button {
                                    editingTaskIndex = idx // use correct idx
                                    showImageSource = true
                                } label: {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.secondary.opacity(0.15))
                                            .frame(width: 44, height: 44)
                                        Image(systemName: "plus")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 24, weight: .bold))
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                        .padding(.vertical, 6)
                    }

                    .onDelete { indices in
                        guard (isEditing && !plan.isCompleted) else { return }
                        plan.tasks.remove(atOffsets: indices)
                    }

                    if isEditing && !plan.isCompleted {
                        Button {
                            plan.tasks.append(TravelTask(title: "New Task"))
                        } label: {
                            Label("Add Task", systemImage: "plus")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(.default, value: plan.tasks)

            // ---- ALL TASKS COMPLETED BUTTON ----
            if allDone && !plan.isCompleted {
                Button {
                    plan.isCompleted = true
                    NotificationHelper.cancelReminder(for: plan)
                    showCompletedAlert = true
                } label: {
                    Text("I'm All Set")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .cornerRadius(12)
                        .shadow(radius: 3)
                        .padding(.horizontal)
                        .padding(.top, 10)
                }
            } else if allDone && plan.isCompleted {
                Button {} label: {
                    Text("All Tasks Completed")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray)
                        .cornerRadius(12)
                        .padding(.horizontal)
                        .padding(.top, 10)
                }
                .disabled(true)
            }

            Spacer(minLength: 0)
        }
        .navigationTitle("Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSubject) { subj in
            SubjectDetailView(subject: subj)
        }
        // IMAGE SOURCE SHEET
        .sheet(isPresented: $showImageSource) {
            ImageSourcePicker { pickedSource in
                imageSource = pickedSource
                showImagePicker = true
            }
        }
        // IMAGE PICKER
        .sheet(isPresented: $showImagePicker) {
            if let imageSource = imageSource {
                FMNImagePicker(sourceType: imageSource) { image in
                    if let img = image {
                        imageToLift = img
                        showImageLift = true
                    }
                    showImagePicker = false
                }
            }
        }
        // SUBJECT LIFT SHEET
        .sheet(isPresented: $showImageLift) {
            if let image = imageToLift, let idx = editingTaskIndex {
                ImageLiftView(uiImage: image) { lifted in
                    // Save new subject image to SwiftData and set its ID
                    if let data = lifted.pngData() {
                        let newSubject = SubjectImage(data: data)
                        modelContext.insert(newSubject)
                        try? modelContext.save()
                        plan.tasks[idx].subjectImageID = newSubject.id
                    }

                    imageToLift = nil
                    editingTaskIndex = nil
                    showImageLift = false
                }
            }
        }
        .alert("Changes Saved!", isPresented: $showSaveAlert) {
            Button("OK") { dismiss() }
        }
        .alert("You did it champ!", isPresented: $showCompletedAlert) {
            Button("OK") { dismiss() }
        }
    }
}

