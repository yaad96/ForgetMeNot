struct NotesDetailView: View {
    let notes: String
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    Text(notes)
                        .font(.body)
                        .padding()
                        .multilineTextAlignment(.leading)
                }
                .opacity(isLoading ? 0 : 1)
                
                if isLoading {
                    Color.black.opacity(0.07).ignoresSafeArea()
                    ProgressView("Loading note…")
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(radius: 10)
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                // Simulate spinner for 0.5 sec (for smooth UI)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isLoading = false
                }
            }
        }
    }
}
