import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \TravelPlan.date, order: .forward) var plans: [TravelPlan]
    @Environment(\.modelContext) private var modelContext

    @State private var showNewPlan = false
    @State private var selectedPlan: TravelPlan?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header Card
                    VStack(spacing: 6) {
                        Text("🧳 ForgetMeNot")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        Text("Let your iPhone remember important details!")
                            .foregroundColor(.secondary)
                            .font(.system(size: 18, weight: .medium))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 14)
                    .background(.ultraThinMaterial)
                    .cornerRadius(26)
                    .shadow(color: Color.blue.opacity(0.04), radius: 8, y: 3)
                    .padding(.horizontal, 14)
                    .padding(.top, 30)

                    // New Plan Button
                    Button {
                        showNewPlan = true
                    } label: {
                        Label("Create a New Travel Plan", systemImage: "plus.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.vertical, 18)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.12), Color.accentColor.opacity(0.11)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                            .shadow(color: Color.accentColor.opacity(0.06), radius: 6, y: 2)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
                    .sheet(isPresented: $showNewPlan) {
                        NewTravelPlanView { newPlan in
                            if let plan = newPlan { selectedPlan = plan }
                            showNewPlan = false
                        }
                    }

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
                                .padding(.top, 28)
                                .padding(.leading, 8)
                            VStack(spacing: 14) {
                                ForEach(incompletePlans) { plan in
                                    PlanCard(plan: plan, isCompleted: false) {
                                        selectedPlan = plan
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            modelContext.delete(plan)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
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
                                    PlanCard(plan: plan, isCompleted: true) {
                                        selectedPlan = plan
                                    }
                                    .opacity(0.7)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            modelContext.delete(plan)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
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
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundColor(.accentColor)
                .font(.system(size: 17, weight: .bold))
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

// MARK: - Plan Card
struct PlanCard: View {
    let plan: TravelPlan
    let isCompleted: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isCompleted ? Color.green.opacity(0.09) : Color.blue.opacity(0.07))
                        .frame(width: 56, height: 56)
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "airplane.departure")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(isCompleted ? .green : .blue)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(plan.name)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(plan.date, style: .date)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .opacity(0.7)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.thinMaterial)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

