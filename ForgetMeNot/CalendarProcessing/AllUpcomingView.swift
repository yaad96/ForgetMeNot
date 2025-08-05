import SwiftUI

struct AllUpcomingView: View {
    @ObservedObject var calendarManager: CalendarManager

    var body: some View {
        List(calendarManager.upcomingItems, id: \.id) { item in
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: item.type == "Event" ? "calendar" : "checkmark.square")
                        .foregroundColor(item.type == "Event" ? .blue : .orange)
                    Text(item.title)
                        .font(.headline)
                    Spacer()
                    Text(item.type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(item.type == "Event" ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                        .cornerRadius(6)
                }
                if let notes = item.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let date = item.date {
                    Text(date, style: .date) + Text(" ") + Text(date, style: .time)
                }
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("All Upcoming")
        .onAppear {
            calendarManager.requestAndFetchEvents()
            calendarManager.requestAndFetchReminders()
        }
    }
}
