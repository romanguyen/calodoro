import Foundation

@MainActor
final class CalendarViewModel: ObservableObject {
  @Published private(set) var events: [CalendarEventSummary] = []
  @Published var selectedEventId: String? = nil
  @Published var errorMessage: String? = nil

  private let calendarClient: GoogleCalendarClient

  init(calendarClient: GoogleCalendarClient) {
    self.calendarClient = calendarClient
  }

  func refresh() async {
    do {
      let fetchedEvents = try await calendarClient.fetchUpcomingEvents()
      events = fetchedEvents
      if let selectedEventId,
         events.first(where: { $0.id == selectedEventId && $0.isAllDay }) == nil {
        self.selectedEventId = nil
      }
      errorMessage = nil
    } catch {
      events = []
      errorMessage = error.localizedDescription
    }
  }

  func clearEvents() {
    events = []
    selectedEventId = nil
    errorMessage = nil
  }

  func createAllDayEvent(title: String) async {
    do {
      let eventId = try await calendarClient.createAllDayEvent(title: title, date: Date())
      await refresh()
      selectedEventId = eventId
      errorMessage = nil
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
