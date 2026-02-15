import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
  let preferences: PreferencesStore
  let notificationService: NotificationService
  let authService: GoogleAuthService
  let calendarClient: GoogleCalendarClient
  let timerService: TimerService

  let timerViewModel: TimerViewModel
  let taskViewModel: TaskViewModel
  let calendarViewModel: CalendarViewModel

  init() {
    let preferences = PreferencesStore()
    let notificationService = NotificationService()
    let authService = GoogleAuthService()
    let calendarClient = GoogleCalendarClient(authService: authService)
    let timerService = TimerService()

    self.preferences = preferences
    self.notificationService = notificationService
    self.authService = authService
    self.calendarClient = calendarClient
    self.timerService = timerService

    self.taskViewModel = TaskViewModel()
    self.timerViewModel = TimerViewModel(
      timerService: timerService,
      notificationService: notificationService,
      calendarClient: calendarClient,
      preferences: preferences
    )
    self.calendarViewModel = CalendarViewModel(calendarClient: calendarClient)
  }
}
