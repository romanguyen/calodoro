import Foundation

final class TimerService {
  private var timerTask: Task<Void, Never>?

  func start(tick: @escaping @MainActor @Sendable () -> Void) {
    stop()
    timerTask = Task { [tick] in
      let clock = ContinuousClock()
      while !Task.isCancelled {
        try? await clock.sleep(for: .seconds(1))
        await tick()
      }
    }
  }

  func stop() {
    timerTask?.cancel()
    timerTask = nil
  }
}
