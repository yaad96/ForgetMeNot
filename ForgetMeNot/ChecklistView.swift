import SwiftUI
import SwiftData

struct ChecklistView: View {
    @Bindable var plan: TravelPlan
    @Environment(\.modelContext) private var modelContext

    @State private var showConfetti = false

    var notificationDate: Date {
        plan.date.addingTimeInterval(plan.reminderOffset)
    }

    var allDone: Bool {
        plan.tasks.allSatisfy { $0.isDone }
    }

    var body: some View {
        VStack {
            Text(plan.name)
                .font(.largeTitle.bold())
                .padding(.top)

            Text("Travel Date: \(plan.date.formatted(date: .abbreviated, time: .shortened))")
                .foregroundColor(.secondary)
            Text("Notification: \(notificationDate.formatted(date: .abbreviated, time: .shortened))")
                .foregroundColor(.secondary)
                .font(.subheadline)

            List {
                ForEach($plan.tasks) { $task in
                    HStack {
                        Button {
                            task.isDone.toggle()
                            if allDone { showConfetti = true }
                        } label: {
                            HStack {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(task.isDone ? .green : .gray)
                                Text(task.title)
                                    .foregroundColor(task.isDone ? .green : .primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .animation(.default, value: plan.tasks)

            Spacer()
        }
        .navigationTitle("Checklist")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(
            ConfettiView(show: $showConfetti)
        )
    }
}

