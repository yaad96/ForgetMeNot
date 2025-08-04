import SwiftUI
import SwiftData
import UIKit

struct TravelPlanDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var plan: TravelPlan
    @Query var subjects: [SubjectImage]
    @State private var selectedSubject: SubjectImage?
    @State private var isEditing = false
    @State private var showSaveAlert = false
    @State private var showCompletedAlert = false

    @State private var tempTravelDate: Date
    @State private var tempNotificationOffset: TimeInterval

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

            // Travel Date (editable only in editing mode and if not completed)
            VStack(alignment: .leading, spacing: 4) {
                Text("Travel Date:")
                    .font(.headline)
                DatePicker("Travel Date", selection: $tempTravelDate, displayedComponents: [.date, .hourAndMinute])
                    .disabled(!(isEditing && !plan.isCompleted))
                    .labelsHidden()
            }
            .padding(.top, 2)
            .padding(.horizontal)

            // Notification Date (editable only in editing mode and if not completed)
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

            // ---- EDIT BUTTON ----
            if !plan.isCompleted {
                Button {
                    isEditing.toggle()
                } label: {
                    Text(isEditing ? "Stop Editing" : "Edit Tasks")
                        .font(.headline)
                        .foregroundColor(isEditing ? .red : .blue)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .padding(.top, 6)
            }

            // Tasks Section
            List {
                Section("Tasks") {
                    ForEach($plan.tasks) { $task in
                        HStack {
                            // Always allow toggling checkboxes unless plan is completed
                            Button {
                                guard !plan.isCompleted else { return }
                                task.isCompleted.toggle()
                            } label: {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(task.isCompleted ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            // Allow editing title only if in editing mode and not completed
                            TextField("Task", text: $task.title)
                                .disabled(!(isEditing && !plan.isCompleted))
                                .strikethrough(task.isCompleted)
                                .foregroundColor(task.isCompleted ? .secondary : .primary)

                            if let id = task.subjectImageID,
                               let subj = subjects.first(where: { $0.id == id }),
                               let thumb = subj.thumbnail {
                                Button {
                                    selectedSubject = subj
                                } label: {
                                    Image(uiImage: thumb)
                                        .resizable()
                                        .frame(width: 32, height: 32)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }
                        }
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

            // ---- SAVE CHANGES BUTTON ----
            if isEditing && !plan.isCompleted {
                Button {
                    plan.date = tempTravelDate
                    plan.reminderOffset = tempNotificationOffset

                    // Cancel any existing, then schedule new notification
                    NotificationHelper.cancelReminder(for: plan)
                    NotificationHelper.scheduleTravelReminder(for: plan, offset: plan.reminderOffset)

                    isEditing = false
                    showSaveAlert = true
                } label: {
                    Text("Save Changes")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .shadow(radius: 3)
                        .padding(.horizontal)
                        .padding(.top, 10)
                }
            }

            // ---- ALL TASKS COMPLETED BUTTON ----
            if allDone && !plan.isCompleted {
                Button {
                    plan.isCompleted = true
                    NotificationHelper.cancelReminder(for: plan)
                    showCompletedAlert = true
                } label: {
                    Text("All Tasks Completed")
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
        .alert("Changes Saved!", isPresented: $showSaveAlert) {
            Button("OK") {
                dismiss()
            }
        }
        .alert("You did it champ!", isPresented: $showCompletedAlert) {
            Button("OK") {
                dismiss()
            }
        }
    }
}

