import SwiftUI
import SwiftData
import UIKit

struct ChecklistView: View {
    @Bindable var plan: TravelPlan
    @Query var subjects: [SubjectImage]
    @State private var selectedSubject: SubjectImage?
    @State private var showConfetti = false

    var notificationDate: Date {
        plan.date.addingTimeInterval(plan.reminderOffset)
    }

    var allDone: Bool {
        plan.tasks.allSatisfy { $0.isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(plan.name)
                .font(.largeTitle.bold())
                .padding(.top)
            Text("Travel Date: \(plan.date.formatted(date: .abbreviated, time: .shortened))")
                .foregroundColor(.secondary)
                .padding(.top, 2)
            Text("Notification: \(notificationDate.formatted(date: .abbreviated, time: .shortened))")
                .foregroundColor(.secondary)
                .font(.subheadline)
                .padding(.bottom, 8)
            List {
                Section("Tasks") {
                    ForEach($plan.tasks) { $task in
                        HStack {
                            Button {
                                task.isCompleted.toggle()
                                if allDone { showConfetti = true }
                            } label: {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(task.isCompleted ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            TextField("Task", text: $task.title)
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
                        plan.tasks.remove(atOffsets: indices)
                    }
                    Button {
                        plan.tasks.append(TravelTask(title: "New Task"))
                    } label: {
                        Label("Add Task", systemImage: "plus")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(.default, value: plan.tasks)
            Spacer(minLength: 0)
        }
        .navigationTitle("Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .sheet(item: $selectedSubject) { subj in
            SubjectDetailView(subject: subj)
        }
        .overlay(
            ConfettiView(show: $showConfetti)
        )
    }
}

