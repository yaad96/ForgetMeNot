import SwiftUI
import SwiftData

struct NewTravelPlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var planName: String = ""
    @State private var travelDate: Date = Date().addingTimeInterval(3600 * 24)
    @State private var tasks: [TravelTask] = [TravelTask(title: "Collect keys"), TravelTask(title: "Pack passport")]

    @State private var notificationType: NotificationType = .oneDay
    @State private var customHours: Int = 0
    @State private var customMinutes: Int = 0
    @State private var customSeconds: Int = 0

    var onDone: (TravelPlan?) -> Void

    var customOffset: TimeInterval {
        -TimeInterval((customHours * 3600) + (customMinutes * 60) + customSeconds)
    }

    var body: some View {
        NavigationStack {
            ScrollView {  // <--- Wrap in ScrollView!
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Plan Name", text: $planName)
                        .font(.title2)
                        .padding(.bottom, 8)

                    DatePicker("Travel Date & Time", selection: $travelDate, displayedComponents: [.date, .hourAndMinute])
                        .padding(.bottom, 12)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("When should we remind you?")
                            .font(.headline)

                        Picker("Notify Me", selection: $notificationType) {
                            ForEach(NotificationType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 2)

                        if notificationType == .custom {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Hours before travel:")
                                    TextField("0", value: $customHours, formatter: NumberFormatter())
                                        .keyboardType(.numberPad)
                                        .frame(width: 60)
                                        .textFieldStyle(.roundedBorder)
                                }
                                HStack {
                                    Text("Minutes before travel:")
                                    TextField("0", value: $customMinutes, formatter: NumberFormatter())
                                        .keyboardType(.numberPad)
                                        .frame(width: 60)
                                        .textFieldStyle(.roundedBorder)
                                }
                                HStack {
                                    Text("Seconds before travel:")
                                    TextField("0", value: $customSeconds, formatter: NumberFormatter())
                                        .keyboardType(.numberPad)
                                        .frame(width: 60)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                    }
                    .padding(.bottom, 16)

                    Text("Tasks")
                        .font(.headline)

                    ForEach($tasks) { $task in
                        HStack {
                            TextField("Task...", text: $task.title)
                            Spacer()
                            Button {
                                if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
                                    tasks.remove(at: idx)
                                }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Button {
                        tasks.append(TravelTask(title: ""))
                    } label: {
                        Label("Add Task", systemImage: "plus")
                            .padding(.vertical, 4)
                    }
                    .padding(.bottom, 12)

                    Spacer(minLength: 10)
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
            .navigationTitle("New Travel Plan")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let cleanTasks = tasks.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
                        guard !planName.isEmpty, !cleanTasks.isEmpty else {
                            onDone(nil)
                            dismiss()
                            return
                        }
                        let reminderOffset: TimeInterval =
                            notificationType == .custom ? customOffset : notificationType.offsetSeconds

                        let plan = TravelPlan(name: planName, date: travelDate, tasks: cleanTasks, reminderOffset: reminderOffset)
                        modelContext.insert(plan)
                        NotificationHelper.scheduleTravelReminder(for: plan, offset: reminderOffset)
                        onDone(plan)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDone(nil)
                        dismiss()
                    }
                }
            }
        }
    }
}

enum NotificationType: String, CaseIterable, Identifiable {
    case oneHour = "1 Hour Before"
    case oneDay = "1 Day Before"
    case custom = "Custom"
    var id: String { rawValue }

    var offsetSeconds: TimeInterval {
        switch self {
        case .oneHour: return -3600
        case .oneDay: return -86400
        case .custom: return 0 // Custom handled separately
        }
    }
}


