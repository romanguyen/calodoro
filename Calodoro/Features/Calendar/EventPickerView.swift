import SwiftUI

struct EventPickerView: View {
  @ObservedObject var calendarViewModel: CalendarViewModel

  var body: some View {
    let allDayEvents = calendarViewModel.events.filter { $0.isAllDay }
    VStack(alignment: .leading, spacing: 6) {
      Text("All-day Events")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Picker("Event", selection: $calendarViewModel.selectedEventId) {
        Text("None").tag(String?.none)
        ForEach(allDayEvents) { event in
          Text(event.title).tag(Optional(event.id))
        }
      }
      .pickerStyle(.radioGroup)
      .labelsHidden()

      if allDayEvents.isEmpty {
        Text("No all-day events")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let errorMessage = calendarViewModel.errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
  }
}
