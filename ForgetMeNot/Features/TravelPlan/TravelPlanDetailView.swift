import SwiftUI
import SwiftData
import UIKit

struct TravelPlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let plan: TravelPlan

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

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // PLAN DETAILS CARD
                    VStack(spacing: 15) {
                        if isEditing {
                            PlanTitleField($planName)
                        } else {
                            Text(plan.name)
                                .font(.system(size: 22, weight: .bold))
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Travel Date & Time")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            if isEditing {
                                DatePicker("", selection: $travelDate, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                            } else {
                                Text(plan.date.formatted(date: .long, time: .shortened))
                                    .font(.callout)
                                    .foregroundColor(.primary)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reminder")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            if isEditing {
                                DatePicker("", selection: $reminderDate, in: ...travelDate, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(.compact)
                            } else {
                                Text((plan.date.addingTimeInterval(plan.reminderOffset)).formatted(date: .long, time: .shortened))
                                    .font(.callout)
                                    .foregroundColor(.primary)
                            }
                        }
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
                                    tasks.append(TravelTask(title: ""))
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

                    // "I'm All Set" Button (only when all tasks completed and not editing)
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
                        // Cancel (cross)
                        Button {
                            cancelEdits()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.red)
                        }
                        // Save (check)
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
                    TextField("What to do?", text: Binding(
                        get: { tasks[idx].title },
                        set: { tasks[idx].title = $0 }
                    ))
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
        //showSaveAlert = true
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

