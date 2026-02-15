import Foundation

@MainActor
final class GoogleCalendarClient {
  enum CalendarError: Error {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case missingEventId
  }

  private let authService: GoogleAuthService
  private let calendarId = "primary"
  private let session: URLSession

  init(authService: GoogleAuthService, session: URLSession = .shared) {
    self.authService = authService
    self.session = session
  }

  func fetchUpcomingEvents() async throws -> [CalendarEventSummary] {
    let accessToken = try await authService.validAccessToken()
    let now = Date()
    let startOfDay = Calendar.current.startOfDay(for: now)
    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? now
    let timeMin = iso8601String(from: startOfDay)
    let timeMax = iso8601String(from: endOfDay)
    var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events")
    components?.queryItems = [
      URLQueryItem(name: "maxResults", value: "50"),
      URLQueryItem(name: "orderBy", value: "startTime"),
      URLQueryItem(name: "singleEvents", value: "true"),
      URLQueryItem(name: "timeMin", value: timeMin),
      URLQueryItem(name: "timeMax", value: timeMax)
    ]

    guard let url = components?.url else {
      return []
    }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw CalendarError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      let message = decodeGoogleError(from: data) ?? "HTTP \(httpResponse.statusCode)"
      throw CalendarError.apiError(statusCode: httpResponse.statusCode, message: message)
    }

    let decoded = try JSONDecoder().decode(EventsResponse.self, from: data)
    return decoded.items.compactMap { item in
      guard let startInfo = parseEventDate(item.start),
            let endInfo = parseEventDate(item.end) else {
        return nil
      }

      let isAllDay = startInfo.isAllDay || endInfo.isAllDay
      return CalendarEventSummary(
        id: item.id,
        title: item.summary ?? "Untitled Event",
        startDate: startInfo.date,
        endDate: endInfo.date,
        isAllDay: isAllDay
      )
    }
  }

  func createEvent(title: String, startDate: Date, endDate: Date) async throws -> String {
    let accessToken = try await authService.validAccessToken()
    let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let payload = EventWriteRequest(
      summary: title,
      start: EventWriteDate(
        dateTime: eventDateTimeString(from: startDate),
        date: nil
      ),
      end: EventWriteDate(
        dateTime: eventDateTimeString(from: endDate),
        date: nil
      ),
      reminders: EventReminders(useDefault: false, overrides: [])
    )

    request.httpBody = try JSONEncoder().encode(payload)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw CalendarError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      let message = decodeGoogleError(from: data) ?? "HTTP \(httpResponse.statusCode)"
      throw CalendarError.apiError(statusCode: httpResponse.statusCode, message: message)
    }

    let decoded = try JSONDecoder().decode(EventWriteResponse.self, from: data)
    guard let eventId = decoded.id else {
      throw CalendarError.missingEventId
    }
    return eventId
  }

  func createAllDayEvent(title: String, date: Date) async throws -> String {
    let accessToken = try await authService.validAccessToken()
    let startOfDay = Calendar.current.startOfDay(for: date)
    let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
    let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let payload: [String: Any] = [
      "summary": title,
      "start": ["date": dateString(from: startOfDay)],
      "end": ["date": dateString(from: endOfDay)],
      "reminders": ["useDefault": false, "overrides": []]
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw CalendarError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      let message = decodeGoogleError(from: data) ?? "HTTP \(httpResponse.statusCode)"
      throw CalendarError.apiError(statusCode: httpResponse.statusCode, message: message)
    }

    let decoded = try JSONDecoder().decode(EventWriteResponse.self, from: data)
    guard let eventId = decoded.id else {
      throw CalendarError.missingEventId
    }
    return eventId
  }

  func updateEventMetadata(eventId: String, summary: String?, description: String?) async throws {
    let accessToken = try await authService.validAccessToken()
    let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events/\(eventId)")!
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    var payload: [String: Any] = [:]
    if let summary {
      payload["summary"] = summary
    }
    if let description {
      payload["description"] = description
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: payload)

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw CalendarError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      let message = decodeGoogleError(from: data) ?? "HTTP \(httpResponse.statusCode)"
      throw CalendarError.apiError(statusCode: httpResponse.statusCode, message: message)
    }
  }

  func updateEvent(eventId: String, startDate: Date, endDate: Date, forceTimed: Bool = false) async throws {
    let accessToken = try await authService.validAccessToken()
    let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarId)/events/\(eventId)")!
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    if forceTimed {
      let safeEndDate = endDate <= startDate
        ? startDate.addingTimeInterval(60)
        : endDate
      let payload: [String: Any] = [
        "start": [
          "dateTime": eventDateTimeString(from: startDate),
          "date": NSNull()
        ],
        "end": [
          "dateTime": eventDateTimeString(from: safeEndDate),
          "date": NSNull()
        ]
      ]
      request.httpBody = try JSONSerialization.data(withJSONObject: payload)
    } else {
    let payload = EventWriteRequest(
      summary: nil,
      start: EventWriteDate(
        dateTime: eventDateTimeString(from: startDate),
        date: nil
      ),
      end: EventWriteDate(
        dateTime: eventDateTimeString(from: endDate),
        date: nil
      ),
      reminders: nil
    )

    request.httpBody = try JSONEncoder().encode(payload)
    }

    let (data, response) = try await session.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw CalendarError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      let message = decodeGoogleError(from: data) ?? "HTTP \(httpResponse.statusCode)"
      throw CalendarError.apiError(statusCode: httpResponse.statusCode, message: message)
    }
  }

  private func iso8601String(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    return formatter.string(from: date)
  }

  private func parseEventDate(_ eventDate: EventDate) -> EventDateInfo? {
    if let dateTime = eventDate.dateTime {
      if let date = iso8601Date(from: dateTime, withFractionalSeconds: true) {
        return EventDateInfo(date: date, isAllDay: false)
      }
      if let date = iso8601Date(from: dateTime, withFractionalSeconds: false) {
        return EventDateInfo(date: date, isAllDay: false)
      }
      return nil
    }

    if let date = eventDate.date {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      formatter.timeZone = TimeZone(secondsFromGMT: 0)
      if let parsed = formatter.date(from: date) {
        return EventDateInfo(date: parsed, isAllDay: true)
      }
    }

    return nil
  }

  private func eventDateTimeString(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    formatter.timeZone = TimeZone.current
    return formatter.string(from: date)
  }

  private func dateString(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone.current
    return formatter.string(from: date)
  }


  private func iso8601Date(from string: String, withFractionalSeconds: Bool) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = withFractionalSeconds
      ? [.withInternetDateTime, .withFractionalSeconds]
      : [.withInternetDateTime]
    return formatter.date(from: string)
  }

  private func decodeGoogleError(from data: Data) -> String? {
    guard let errorResponse = try? JSONDecoder().decode(GoogleErrorResponse.self, from: data) else {
      return nil
    }
    if let message = errorResponse.error.message {
      if let detail = errorResponse.error.errors?.first {
        return "\(message) (\(detail.reason ?? "unknown"))"
      }
      return message
    }
    return nil
  }
}

private struct GoogleErrorResponse: Decodable {
  struct ErrorDetail: Decodable {
    let code: Int?
    let message: String?
    let status: String?
    let errors: [ErrorItem]?
  }

  struct ErrorItem: Decodable {
    let domain: String?
    let reason: String?
    let message: String?
  }

  let error: ErrorDetail
}

extension GoogleCalendarClient.CalendarError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "Calendar API response invalid"
    case .apiError(let statusCode, let message):
      return "Calendar API error (\(statusCode)): \(message)"
    case .missingEventId:
      return "Calendar event id missing"
    }
  }
}

private struct EventsResponse: Decodable {
  let items: [EventItem]
}

private struct EventItem: Decodable {
  let id: String
  let summary: String?
  let start: EventDate
  let end: EventDate
}

private struct EventDate: Decodable {
  let dateTime: String?
  let date: String?
}

private struct EventWriteRequest: Encodable {
  let summary: String?
  let start: EventWriteDate
  let end: EventWriteDate
  let reminders: EventReminders?
}

private struct EventWriteDate: Encodable {
  let dateTime: String
  let date: String?
}

private struct EventReminders: Encodable {
  let useDefault: Bool
  let overrides: [EventReminder]
}

private struct EventReminder: Encodable {
  let method: String
  let minutes: Int
}

private struct EventWriteResponse: Decodable {
  let id: String?
}

private struct EventDateInfo {
  let date: Date
  let isAllDay: Bool
}
