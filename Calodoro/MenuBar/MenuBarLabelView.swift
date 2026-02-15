import SwiftUI

struct MenuBarLabelView: View {
  @ObservedObject var timerViewModel: TimerViewModel

  private var labelText: String {
    switch timerViewModel.state {
    case .idle:
      return "Calodoro"
    case .running:
      return timerViewModel.formattedDisplay
    case .paused:
      return "Paused \(timerViewModel.formattedDisplay)"
    }
  }

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "timer")
      Text(labelText)
        .monospacedDigit()
    }
  }
}
