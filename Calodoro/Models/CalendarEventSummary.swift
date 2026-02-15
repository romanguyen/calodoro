import Foundation

struct CalendarEventSummary: Identifiable, Hashable {
  let id: String
  let title: String
  let startDate: Date
  let endDate: Date
  let isAllDay: Bool
}
