import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \TravelPlan.date, order: .forward) var plans: [TravelPlan]
    @Environment(\.modelContext) private var modelContext

    @State private var showNewPlan = false
    @State private var selectedPlan: TravelPlan?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Custom app header
                VStack(spacing: 0) {
                    Text("🧳 ForgetMeNot")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                    Text("Let your iPhone remember important details!")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
                .padding(.bottom, 18)
                .background(
                    Color(.systemGray6)
                        .opacity(0.65)
                        .ignoresSafeArea(edges: .top)
                )

                // "Create a New Travel Plan" button
                Button(action: {
                    showNewPlan = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Create a New Travel Plan")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.top, 10)
                .sheet(isPresented: $showNewPlan) {
                    NewTravelPlanView { newPlan in
                        if let plan = newPlan {
                            selectedPlan = plan
                        }
                        showNewPlan = false
                    }
                }

                // List of plans
                List {
                    ForEach(plans) { plan in
                        Button {
                            selectedPlan = plan
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.name)
                                    .font(.headline)
                                Text(plan.date, style: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .onDelete { idxSet in
                        for idx in idxSet {
                            modelContext.delete(plans[idx])
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .navigationDestination(item: $selectedPlan) { plan in
                    ChecklistView(plan: plan)
                }

                Spacer()
            }
        }
    }
}

