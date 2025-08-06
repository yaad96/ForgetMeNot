import SwiftUI
import SwiftData

struct ContentView: View {
    

    @Query(sort: \TravelPlan.date, order: .forward) var plans: [TravelPlan]
    @Environment(\.modelContext) private var modelContext

    @State private var showNewPlan = false
    @State private var selectedPlan: TravelPlan?
    
    @State private var showAllUpcoming = false


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Card
                    VStack(spacing: 4) {
                        

                            Text("🧳ForgetMeNot")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundColor(.accentColor)
                                .shadow(color: .accentColor.opacity(0.04), radius: 2, y: 1)
                                .padding(.bottom, 2)
                            Text("Let your iPhone remember important details!")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 18)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.systemBackground).opacity(0.72))
                                .shadow(color: .accentColor.opacity(0.09), radius: 5, y: 2)
                        )
                        .padding(.horizontal, 14)
                        .padding(.top, 22)

                        // Sleek Modern Buttons
                        HStack(spacing: 10) {
                            Button {
                                showNewPlan = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("New Plan")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 18)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.accentColor.opacity(0.15), Color.blue.opacity(0.12)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            )
                                        )
                                )
                            }
                            .foregroundColor(.accentColor)
                            .buttonStyle(.plain)
                            .sheet(isPresented: $showNewPlan) {
                                NewTravelPlanView { newPlan in
                                    if let plan = newPlan { selectedPlan = plan }
                                    showNewPlan = false
                                }
                            }

                            Button {
                                showAllUpcoming = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "rectangle.stack")
                                    Text("From Calendar")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 18)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.blue.opacity(0.14), Color.accentColor.opacity(0.13)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing
                                            )
                                        )
                                )
                            }
                            .foregroundColor(.accentColor)
                            .buttonStyle(.plain)
                            .sheet(isPresented: $showAllUpcoming) {
                                NavigationStack {
                                    AllUpcomingView(calendarManager: CalendarManager())
                                }
                            }
                        }
                        .padding(.top, 4)
                        .padding(.horizontal, 18)



                    // Sections
                    let incompletePlans = plans.filter { !$0.isCompleted }
                    let completedPlans = plans.filter { $0.isCompleted }

                    if plans.isEmpty {
                        VStack {
                            Spacer(minLength: 60)
                            Text("No travel plans yet.\nTap 'Create a New Travel Plan' to get started!")
                                .font(.title3.weight(.medium))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                    } else {
                        // Incomplete
                        if !incompletePlans.isEmpty {
                            SectionHeader(text: "Upcoming Plans", systemImage: "clock")
                                .padding(.top , 28)
                                .padding(.bottom, 8)
                                .padding(.leading, 8)
                            VStack(spacing: 14) {
                                ForEach(incompletePlans) { plan in
                                    PlanCard(
                                        plan: plan,
                                        isCompleted: false,
                                        onTap: {
                                        selectedPlan = plan
                                        },
                                        onDelete: { deepDeleteTravelPlan(plan, modelContext: modelContext) }
                                    )
                                }

                                

                            }
                            .padding(.horizontal, 14)
                        }

                        // Completed
                        if !completedPlans.isEmpty {
                            SectionHeader(text: "Completed", systemImage: "checkmark.seal")
                                .padding(.top, incompletePlans.isEmpty ? 36 : 24)
                                .padding(.leading, 8)
                            VStack(spacing: 14) {
                                ForEach(completedPlans) { plan in
                                    PlanCard(
                                        plan: plan,
                                        isCompleted: true,
                                        onTap: {
                                        selectedPlan = plan
                                        },
                                        onDelete: { deepDeleteTravelPlan(plan, modelContext: modelContext) }
                                    )
                                    
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 16)
                        }
                    }

                    Spacer(minLength: 60)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationDestination(item: $selectedPlan) { plan in
                TravelPlanDetailView(plan: plan)
            }
        }
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let text: String
    let systemImage: String
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
                .font(.system(size: 15, weight: .semibold))
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.leading, 2)
        .padding(.bottom, 3)
    }
}


// MARK: - Plan Card
struct PlanCard: View {
    let plan: TravelPlan
    let isCompleted: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onTap) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isCompleted ? Color.green.opacity(0.08) : Color.blue.opacity(0.06))
                        .frame(width: 42, height: 42)
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "airplane.departure")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(isCompleted ? .green : .blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 7) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(plan.date, style: .date)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray.opacity(0.6))
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.plain)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.75))
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(.thinMaterial)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
    }
}

