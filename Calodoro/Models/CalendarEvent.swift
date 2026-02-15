import Foundation
import SwiftData

@Model
final class CalendarEvent {
  var id: UUID
  var eventId: String
  var title: String
  var startDate: Date
  var endDate: Date
  var source: String

  init(
    id: UUID = UUID(),
    eventId: String,
    title: String,
    startDate: Date,
    endDate: Date,
    source: String
  ) {
    self.id = id
    self.eventId = eventId
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.source = source
  }
}
