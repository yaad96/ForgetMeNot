import SwiftUI
import SwiftData
import UIKit

struct TravelPlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: TravelPlan // NOT @Bindable!

    @Query var subjects: [SubjectImage]

    // --- Local Editing State ---
    @State private var isEditing = false
    @State private var planName: String = ""
    @State private var travelDate: Date = .now
    @State private var reminderDate: Date = .now
    @State private var tasks: [TravelTask] = []

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

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 26) {
                    // PLAN DETAILS CARD
                    VStack(spacing: 20) {
                        if isEditing {
                            PlanTitleField()
                        } else {
                            Text(plan.name)
                                .font(.system(size: 28, weight: .bold))
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }


                        VStack(alignment: .leading, spacing: 14) {
                            Text("Travel Date & Time")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.secondary)
                            if isEditing {
                                DatePicker("", selection: $travelDate, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                            } else {
                                Text(plan.date.formatted(date: .long, time: .shortened))
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text("Reminder")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.secondary)
                            if isEditing {
                                DatePicker("", selection: $reminderDate, in: ...travelDate, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                            } else {
                                Text((plan.date.addingTimeInterval(plan.reminderOffset)).formatted(date: .long, time: .shortened))
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(22)
                    .shadow(color: Color.black.opacity(0.08), radius: 16, y: 6)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)

                    // TASKS CARD
                    VStack(spacing: 18) {
                        HStack {
                            Text("Tasks")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                        }

                        if isEditing {
                            ForEach(tasks.indices, id: \.self) { idx in
                                taskRow(idx: idx, editing: true)
                            }
                            Button {
                                withAnimation(.spring()) {
                                    tasks.append(TravelTask(title: ""))
                                }
                            } label: {
                                Label("Add Task", systemImage: "plus.circle.fill")
                                    .font(.system(size: 19, weight: .semibold))
                                    .padding(.vertical, 11)
                                    .padding(.horizontal, 18)
                                    .background(Color.accentColor.opacity(0.92))
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                                    .shadow(color: Color.accentColor.opacity(0.17), radius: 8, y: 2)
                            }
                            .padding(.top, 8)
                            .frame(maxWidth: .infinity, alignment: .center)
                        } else {
                            ForEach(plan.tasks.indices, id: \.self) { idx in
                                taskRow(idx: idx, editing: false)
                            }
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(22)
                    .shadow(color: Color.black.opacity(0.07), radius: 14, y: 4)
                    .padding(.horizontal, 10)

                    // "I'm All Set" Button (only when all tasks completed and not editing)
                    if !isEditing && plan.tasks.count > 0 && plan.tasks.allSatisfy({ $0.isCompleted }) && !plan.isCompleted {
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
                    } else if !isEditing && plan.tasks.count > 0 && plan.tasks.allSatisfy({ $0.isCompleted }) && plan.isCompleted {
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

                    Spacer(minLength: 20)
                }
                .padding(.bottom, 32)
            }
            .navigationTitle("Plan Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Only show edit icon if plan is not completed, and not in editing mode
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !plan.isCompleted {
                        if isEditing {
                            Button {
                                saveEdits()
                            } label: {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.green)
                            }
                        } else {
                            Button {
                                enterEditMode()
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button("Cancel") {
                            cancelEdits()
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
            .alert("You did it champ!", isPresented: $showCompletedAlert) {
                Button("OK") { dismiss() }
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
        .onAppear(perform: initializeEditFields)
    }
    
    @ViewBuilder
    func PlanTitleField() -> some View {
        TextField("Give your plan a name...", text: $planName)
            .padding(.vertical, 16)
            .padding(.horizontal, 22)
            .font(.system(size: 22, weight: .semibold))
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.03), radius: 2, y: 1)
    }


    // MARK: - Task Row
    @ViewBuilder
    func taskRow(idx: Int, editing: Bool) -> some View {
        let task = editing ? tasks[idx] : plan.tasks[idx]
        HStack(alignment: .center, spacing: 12) {
            Button {
                if editing {
                    tasks[idx].isCompleted.toggle()
                } else if !plan.isCompleted {
                    plan.tasks[idx].isCompleted.toggle()
                }
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Group {
                if editing {
                    TextField("What to do?", text: Binding(
                        get: { tasks[idx].title },
                        set: { tasks[idx].title = $0 }
                    ))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .font(.system(size: 17, weight: .regular))
                } else {
                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .font(.system(size: 17, weight: .regular))
                        .padding(.vertical, 12)
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
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.9), lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.13), radius: 8, y: 3)
                        .padding(.trailing, 2)
                        .transition(.scale.combined(with: .opacity))
                }
                .buttonStyle(.plain)
            } else if editing {
                Button {
                    editingTaskIndex = idx
                    showImageSourceDialog = true
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray5))
                            .frame(width: 48, height: 48)
                        Image(systemName: "photo.on.rectangle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .foregroundColor(.blue.opacity(0.82))
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .foregroundColor(.accentColor)
                            .background(Color.white, in: Circle())
                            .frame(width: 21, height: 21)
                            .offset(x: 14, y: 14)
                            .shadow(color: Color.black.opacity(0.13), radius: 2, x: 1, y: 1)
                    }
                }
                .buttonStyle(.plain)
                .padding(.trailing, 2)
            }

            if editing && tasks.count > 1 {
                Button {
                    tasks.remove(at: idx)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 22, weight: .semibold))
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Editing Logic
    private func initializeEditFields() {
        planName = plan.name
        travelDate = plan.date
        reminderDate = plan.date.addingTimeInterval(plan.reminderOffset)
        tasks = plan.tasks
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
        plan.name = planName
        plan.date = travelDate
        plan.reminderOffset = reminderDate.timeIntervalSince(travelDate)
        plan.tasks = cleanTasks
        NotificationHelper.cancelReminder(for: plan)
        NotificationHelper.scheduleTravelReminder(for: plan, offset: plan.reminderOffset)
        isEditing = false
        showSaveAlert = true
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
}

