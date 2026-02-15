import Foundation

enum TimerMode: String, CaseIterable, Identifiable {
  case pomodoro
  case timer

  var id: String { rawValue }

  var title: String {
    switch self {
    case .pomodoro:
      return "Pomodoro"
    case .timer:
      return "Timer"
    }
  }
}
