import Foundation
import SwiftData

@Model
final class PomodoroSession {
  var id: UUID
  var taskTitle: String
  var startDate: Date
  var endDate: Date?
  var calendarEventId: String?

  init(
    id: UUID = UUID(),
    taskTitle: String,
    startDate: Date = Date(),
    endDate: Date? = nil,
    calendarEventId: String? = nil
  ) {
    self.id = id
    self.taskTitle = taskTitle
    self.startDate = startDate
    self.endDate = endDate
    self.calendarEventId = calendarEventId
  }
}
