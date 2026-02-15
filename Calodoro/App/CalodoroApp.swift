import SwiftUI
import SwiftData

@main
struct CalodoroApp: App {
  @StateObject private var environment = AppEnvironment()

  var body: some Scene {
    MenuBarExtra {
      MenuBarView(
        timerViewModel: environment.timerViewModel,
        taskViewModel: environment.taskViewModel,
        calendarViewModel: environment.calendarViewModel,
        notificationService: environment.notificationService,
        authService: environment.authService,
        preferences: environment.preferences
      )
    } label: {
      MenuBarLabelView(timerViewModel: environment.timerViewModel)
    }
    .menuBarExtraStyle(.window)
    .modelContainer(for: [PomodoroSession.self, TaskItem.self, CalendarEvent.self])

    Settings {
      PreferencesView(preferences: environment.preferences)
    }
    .modelContainer(for: [PomodoroSession.self, TaskItem.self, CalendarEvent.self])
  }
}
