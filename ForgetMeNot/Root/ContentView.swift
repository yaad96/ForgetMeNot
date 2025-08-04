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
                // Header
                VStack(spacing: 4) {
                    Text("🧳 ForgetMeNot")
                        .font(.largeTitle.bold())
                        .foregroundColor(.blue)
                    Text("Let your iPhone remember important details!")
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)

                Button {
                    showNewPlan = true
                } label: {
                    Label("Create a New Travel Plan", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .sheet(isPresented: $showNewPlan) {
                    NewTravelPlanView { newPlan in
                        if let plan = newPlan { selectedPlan = plan }
                        showNewPlan = false
                    }
                }

                if plans.isEmpty {
                    Text("No travel plans yet.\nTap 'Create a New Travel Plan' to get started!")
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 60)
                        .frame(maxWidth: .infinity)
                } else {
                    List {
                        ForEach(plans) { plan in
                            Button {
                                selectedPlan = plan
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(plan.name).font(.headline)
                                    Text(plan.date, style: .date).foregroundColor(.gray)
                                }
                            }
                        }
                        .onDelete { idx in
                            idx.map { modelContext.delete(plans[$0]) }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                Spacer()
            }
            .navigationDestination(item: $selectedPlan) { plan in
                TravelPlanDetailView(plan: plan)
            }
        }
    }
}

