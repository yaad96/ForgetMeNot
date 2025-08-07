import SwiftUI

struct AllUpcomingView: View {
    @Environment(\.dismiss) private var dismissSheet

    @ObservedObject var calendarManager: CalendarManager
    @Binding var navPath: NavigationPath

    @State private var isNewPlanActive = false
    @State private var pendingPlanName: String = ""
    @State private var pendingTravelDate: Date = .now
    @State private var pendingReminderDate: Date = .now
    @State private var pendingTasks: [TravelTask] = []
    @State private var isGeneratingPlan = false
    @State private var notesToShow = ""

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(calendarManager.upcomingItems, id: \.id) { item in
                        EventCard(
                            item: item,
                            onCreatePlan: {
                                isGeneratingPlan = true
                                fetchPlanSuggestionOpenAI(
                                    eventTitle: item.title,
                                    eventDate: item.date ?? .now,
                                    eventDescription: item.notes
                                ) { suggestion in
                                    DispatchQueue.main.async {
                                        isGeneratingPlan = false
                                        if let suggestion = suggestion {
                                            let formatter = ISO8601DateFormatter()
                                            let notifDate = formatter.date(from: suggestion.notification_date) ?? (item.date ?? .now)
                                            let tasks = suggestion.tasks.map { TravelTask(title: $0) }
                                            pendingPlanName = item.title
                                            pendingTravelDate = item.date ?? .now
                                            pendingReminderDate = notifDate
                                            pendingTasks = tasks
                                        } else {
                                            pendingPlanName = item.title
                                            pendingTravelDate = item.date ?? .now
                                            pendingReminderDate = item.date ?? .now
                                            pendingTasks = [
                                                TravelTask(title: "Task A"),
                                                TravelTask(title: "Task B")
                                            ]

                                        }
                                        isNewPlanActive = true
                                    }
                                }
                            },
                            onShowDetails: {
                                notesToShow = item.notes ?? ""
                            },
                            onCreateBlank: {
                                            // Generate "Plan Yourself"
                                            pendingPlanName = item.title
                                            pendingTravelDate = item.date ?? .now
                                            pendingReminderDate = item.date ?? .now
                                            pendingTasks = [
                                                TravelTask(title: "Task A"),
                                                TravelTask(title: "Task B")
                                            ]

                                            isNewPlanActive = true // << navigation push!
                            }
                        )
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 9)
            }
            .blur(radius: isGeneratingPlan ? 2 : 0)
            .disabled(isGeneratingPlan)

            // Spinner overlay
            if isGeneratingPlan {
                Color.black.opacity(0.07).ignoresSafeArea()
                ProgressView("Generating plan with ChatGPT…")
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(radius: 10)
            }
        }
        .navigationDestination(isPresented: $isNewPlanActive) {
            NewTravelPlanView(
                planName: pendingPlanName,
                travelDate: pendingTravelDate,
                reminderDate: pendingReminderDate,
                tasks: pendingTasks
            ) { newPlan in
                if let plan = newPlan {
                    navPath.removeLast(navPath.count) // Pop to home
                    navPath.append(AppNav.planDetail(plan)) // Show plan details
                } else {
                    navPath.removeLast(navPath.count) // Pop to home if cancelled
                }
            }
        }

        
        .sheet(isPresented: Binding<Bool>(
            get: { !notesToShow.isEmpty },
            set: { newValue in
                if !newValue { notesToShow = "" }
            }
        )) {
            NotesDetailView(notes: notesToShow)
        }
        .navigationTitle("All Upcoming Events")
        .onAppear {
            calendarManager.requestAndFetchEvents()
            calendarManager.requestAndFetchReminders()
        }
    }
}

// MARK: - Modern Event Card
struct EventCard: View {
    let item: UpcomingItem
    var onCreatePlan: () -> Void
    var onShowDetails: () -> Void
    var onCreateBlank: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: item.type == "Event" ? "calendar" : "checkmark.square")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundColor(item.type == "Event" ? .blue : .orange)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(item.type == "Event" ? Color.blue.opacity(0.10) : Color.orange.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.97)
                    if let date = item.date {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Text(date, style: .date)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text(date, style: .time)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
            }

            if let notes = item.notes, !notes.isEmpty {
                Button("See Event Details") {
                    onShowDetails()
                }
                .font(.system(size: 13, weight: .medium))
                .padding(.vertical, 5)
                .padding(.horizontal, 13)
                .background(Color.accentColor.opacity(0.11))
                .foregroundColor(.accentColor)
                .cornerRadius(8)
                .buttonStyle(.plain)
            }

            Button(action: onCreatePlan) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Generate Smart Travel Plan")
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.vertical, 7)
                .padding(.horizontal, 16)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.13))
                )
            }
            .foregroundColor(.blue)
            .buttonStyle(.plain)
            
            Button(action: onCreateBlank) {
                            HStack(spacing: 8) {
                                Image(systemName: "wand.and.stars")
                                Text("Generate Plan Yourself")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.vertical, 7)
                            .padding(.horizontal, 16)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.13))
                            )
                        }
                        .foregroundColor(.orange)
                        .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.thinMaterial)
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.accentColor.opacity(0.08), lineWidth: 1)
        )
    }
}

