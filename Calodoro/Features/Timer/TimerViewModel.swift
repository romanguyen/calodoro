import Foundation

@MainActor
final class TimerViewModel: ObservableObject {
  @Published private(set) var state: TimerState = .idle
  @Published private(set) var elapsedSeconds: Int = 0
  @Published private(set) var currentTaskTitle: String = ""
  @Published var calendarSyncMessage: String? = nil
  @Published var mode: TimerMode = .pomodoro
  @Published private(set) var phase: TimerPhase = .work

  private let timerService: TimerService
  private let notificationService: NotificationService
  private let calendarClient: GoogleCalendarClient
  private let preferences: PreferencesStore
  private var durationSeconds: Int = 0
  private var totalWorkSeconds: Int = 0
  private var activeEventId: String?
  private var activeEventIsAllDay: Bool = false
  private var sessionStartDate: Date?

  init(
    timerService: TimerService,
    notificationService: NotificationService,
    calendarClient: GoogleCalendarClient,
    preferences: PreferencesStore
  ) {
    self.timerService = timerService
    self.notificationService = notificationService
    self.calendarClient = calendarClient
    self.preferences = preferences
  }

  var displaySeconds: Int {
    switch mode {
    case .pomodoro:
      let targetDuration = state == .idle ? preferences.pomodoroMinutes * 60 : durationSeconds
      return max(0, targetDuration - elapsedSeconds)
    case .timer:
      return elapsedSeconds
    }
  }

  var formattedDisplay: String {
    TimeFormatter.string(from: displaySeconds)
  }

  var statusText: String {
    switch state {
    case .idle:
      return mode == .pomodoro ? "Ready to focus" : "Ready to time"
    case .running:
      if mode == .pomodoro, phase == .rest {
        return "Break"
      }
      return mode == .pomodoro ? "Focusing" : "Timing"
    case .paused:
      return "Paused"
    }
  }

  func start(taskTitle: String, existingEventId: String?, existingEventIsAllDay: Bool) {
    durationSeconds = mode == .pomodoro ? preferences.pomodoroMinutes * 60 : 0
    currentTaskTitle = taskTitle
    elapsedSeconds = 0
    totalWorkSeconds = 0
    activeEventId = existingEventId
    activeEventIsAllDay = existingEventIsAllDay
    sessionStartDate = Date()
    calendarSyncMessage = nil
    phase = .work
    state = .running
    timerService.start { [weak self] in
      self?.handleTick()
    }
  }

  func pause() {
    guard state == .running else { return }
    state = .paused
    timerService.stop()
  }

  func resume() {
    guard state == .paused else { return }
    state = .running
    timerService.start { [weak self] in
      self?.handleTick()
    }
  }

  func stop() {
    guard state != .idle else { return }
    let includeCurrentWork = mode == .timer || phase == .work
    finalizeSession(includeCurrentWork: includeCurrentWork)
  }

  private func handleTick() {
    guard state == .running else { return }
    elapsedSeconds += 1
    guard mode == .pomodoro, durationSeconds > 0, elapsedSeconds >= durationSeconds else {
      return
    }

    if phase == .work {
      completeWorkSegment(shouldNotify: true)
    } else {
      if preferences.notificationsEnabled, preferences.breakEndNotificationsEnabled {
        Task {
          await notificationService.notifyBreakEnded()
        }
      }
      startWorkCycle()
    }
  }

  private func completeWorkSegment(shouldNotify: Bool) {
    totalWorkSeconds += elapsedSeconds

    if shouldNotify, preferences.notificationsEnabled, preferences.workEndNotificationsEnabled {
      Task {
        await notificationService.notifyPomodoroEnded(taskTitle: currentTaskTitle)
      }
    }

    if preferences.shortBreakMinutes > 0 {
      startBreak()
    } else {
      startWorkCycle()
    }
  }

  private func startBreak() {
    phase = .rest
    durationSeconds = preferences.shortBreakMinutes * 60
    elapsedSeconds = 0
    state = .running
    timerService.start { [weak self] in
      self?.handleTick()
    }
  }

  private func stopBreak() {
    state = .idle
    timerService.stop()
    resetSession()
  }

  private func startWorkCycle() {
    phase = .work
    durationSeconds = preferences.pomodoroMinutes * 60
    elapsedSeconds = 0
    state = .running
    timerService.start { [weak self] in
      self?.handleTick()
    }
  }

  private func finalizeSession(includeCurrentWork: Bool) {
    if includeCurrentWork {
      totalWorkSeconds += elapsedSeconds
    }

    syncCalendarIfNeeded()

    state = .idle
    timerService.stop()
    resetSession()
  }

  private func syncCalendarIfNeeded() {
    guard totalWorkSeconds > 0 else { return }
    let startDate = sessionStartDate ?? Date()
    let endDate = startDate.addingTimeInterval(TimeInterval(totalWorkSeconds))
    let eventId = activeEventId
    let title = currentTaskTitle
    let isAllDay = activeEventIsAllDay

    Task {
      await syncCalendar(
        eventId: eventId,
        title: title,
        startDate: startDate,
        endDate: endDate,
        isAllDay: isAllDay
      )
    }
  }

  private func resetSession() {
    elapsedSeconds = 0
    totalWorkSeconds = 0
    activeEventId = nil
    activeEventIsAllDay = false
    sessionStartDate = nil
    phase = .work
  }

  private func syncCalendar(
    eventId: String?,
    title: String,
    startDate: Date,
    endDate: Date,
    isAllDay: Bool
  ) async {
    guard endDate > startDate else { return }
    do {
      if let eventId {
        try await calendarClient.updateEvent(
          eventId: eventId,
          startDate: startDate,
          endDate: endDate,
          forceTimed: isAllDay
        )
      } else {
        _ = try await calendarClient.createEvent(title: title, startDate: startDate, endDate: endDate)
      }
      calendarSyncMessage = nil
    } catch {
      calendarSyncMessage = error.localizedDescription
    }
  }
}
