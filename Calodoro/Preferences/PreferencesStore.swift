import Foundation

@MainActor
final class PreferencesStore: ObservableObject {
  @Published var pomodoroMinutes: Int {
    didSet { userDefaults.set(pomodoroMinutes, forKey: Keys.pomodoroMinutes) }
  }
  @Published var shortBreakMinutes: Int {
    didSet { userDefaults.set(shortBreakMinutes, forKey: Keys.shortBreakMinutes) }
  }
  @Published var longBreakMinutes: Int {
    didSet { userDefaults.set(longBreakMinutes, forKey: Keys.longBreakMinutes) }
  }
  @Published var notificationsEnabled: Bool {
    didSet { userDefaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
  }
  @Published var workEndNotificationsEnabled: Bool {
    didSet { userDefaults.set(workEndNotificationsEnabled, forKey: Keys.workEndNotificationsEnabled) }
  }
  @Published var breakEndNotificationsEnabled: Bool {
    didSet { userDefaults.set(breakEndNotificationsEnabled, forKey: Keys.breakEndNotificationsEnabled) }
  }

  private let userDefaults: UserDefaults

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults

    var pomodoro = userDefaults.integer(forKey: Keys.pomodoroMinutes)
    if pomodoro == 0 { pomodoro = 25 }

    var shortBreak = userDefaults.integer(forKey: Keys.shortBreakMinutes)
    if shortBreak == 0 { shortBreak = 5 }

    var longBreak = userDefaults.integer(forKey: Keys.longBreakMinutes)
    if longBreak == 0 { longBreak = 15 }

    let notificationsEnabled: Bool
    if userDefaults.object(forKey: Keys.notificationsEnabled) == nil {
      notificationsEnabled = true
    } else {
      notificationsEnabled = userDefaults.bool(forKey: Keys.notificationsEnabled)
    }

    let workEndNotificationsEnabled: Bool
    if userDefaults.object(forKey: Keys.workEndNotificationsEnabled) == nil {
      workEndNotificationsEnabled = true
    } else {
      workEndNotificationsEnabled = userDefaults.bool(forKey: Keys.workEndNotificationsEnabled)
    }

    let breakEndNotificationsEnabled: Bool
    if userDefaults.object(forKey: Keys.breakEndNotificationsEnabled) == nil {
      breakEndNotificationsEnabled = false
    } else {
      breakEndNotificationsEnabled = userDefaults.bool(forKey: Keys.breakEndNotificationsEnabled)
    }

    self.pomodoroMinutes = pomodoro
    self.shortBreakMinutes = shortBreak
    self.longBreakMinutes = longBreak
    self.notificationsEnabled = notificationsEnabled
    self.workEndNotificationsEnabled = workEndNotificationsEnabled
    self.breakEndNotificationsEnabled = breakEndNotificationsEnabled
  }

  private enum Keys {
    static let pomodoroMinutes = "preferences.pomodoroMinutes"
    static let shortBreakMinutes = "preferences.shortBreakMinutes"
    static let longBreakMinutes = "preferences.longBreakMinutes"
    static let notificationsEnabled = "preferences.notificationsEnabled"
    static let workEndNotificationsEnabled = "preferences.workEndNotificationsEnabled"
    static let breakEndNotificationsEnabled = "preferences.breakEndNotificationsEnabled"
  }
}
