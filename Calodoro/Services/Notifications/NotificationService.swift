import Foundation
import UserNotifications

@MainActor
final class NotificationService {
  private let center = UNUserNotificationCenter.current()

  func requestAuthorization() async {
    do {
      _ = try await center.requestAuthorization(options: [.alert, .sound])
    } catch {
      return
    }
  }

  func notifyPomodoroEnded(taskTitle: String) async {
    let content = UNMutableNotificationContent()
    content.title = "Pomodoro Complete"
    content.body = taskTitle.isEmpty ? "Time to take a break." : "Finished: \(taskTitle)"
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )

    do {
      try await center.add(request)
    } catch {
      return
    }
  }

  func notifyBreakEnded() async {
    let content = UNMutableNotificationContent()
    content.title = "Break Complete"
    content.body = "Back to work."
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil
    )

    do {
      try await center.add(request)
    } catch {
      return
    }
  }
}
