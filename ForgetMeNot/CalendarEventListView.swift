import SwiftUI

struct CalendarEventListView: View {
    @StateObject private var calendarManager = CalendarManager()
    @State private var permissionDenied = false

    var body: some View {
        NavigationView {
            List(calendarManager.events, id: \.eventIdentifier) { event in
                VStack(alignment: .leading) {
                    Text(event.title)
                        .font(.headline)
                    if let location = event.location {
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Text(event.startDate, style: .date)
                        .font(.caption)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Next Month's Events")
            .onAppear {
                calendarManager.requestAccess { granted in
                    if granted {
                        calendarManager.fetchEvents()
                    } else {
                        permissionDenied = true
                    }
                }
            }
            .alert(isPresented: $permissionDenied) {
                Alert(title: Text("Permission Denied"), message: Text("Please enable Calendar access in Settings."), dismissButton: .default(Text("OK")))
            }
        }
    }
}
