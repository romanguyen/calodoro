import SwiftUI

struct PreferencesView: View {
  @ObservedObject var preferences: PreferencesStore
  var embedded: Bool = false
  @State private var workPreset: WorkPreset
  @State private var breakPreset: BreakPreset

  init(preferences: PreferencesStore, embedded: Bool = false) {
    self._preferences = ObservedObject(wrappedValue: preferences)
    self.embedded = embedded
    _workPreset = State(initialValue: WorkPreset.from(minutes: preferences.pomodoroMinutes))
    _breakPreset = State(initialValue: BreakPreset.from(minutes: preferences.shortBreakMinutes))
  }

  var body: some View {
    let content = VStack(alignment: .leading, spacing: 16) {
      GroupBox {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text("Work")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer()
            Picker("Work", selection: $workPreset) {
              ForEach(WorkPreset.allCases) { preset in
                Text(preset.title).tag(preset)
              }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: workPreset) { _, newValue in
              applyWorkPreset(newValue)
            }
          }

          if workPreset == .custom {
            HStack {
              Text("Custom")
                .font(.subheadline)
              TextField(
                "Minutes",
                value: $preferences.pomodoroMinutes,
                format: .number
              )
              .frame(width: 60)
              .textFieldStyle(.roundedBorder)
              Text("min")
                .foregroundStyle(.secondary)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      GroupBox {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text("Break")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer()
            Picker("Break", selection: $breakPreset) {
              ForEach(BreakPreset.allCases) { preset in
                Text(preset.title).tag(preset)
              }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: breakPreset) { _, newValue in
              applyBreakPreset(newValue)
            }
          }

          if breakPreset == .custom {
            HStack {
              Text("Custom")
                .font(.subheadline)
              TextField(
                "Minutes",
                value: $preferences.shortBreakMinutes,
                format: .number
              )
              .frame(width: 60)
              .textFieldStyle(.roundedBorder)
              Text("min")
                .foregroundStyle(.secondary)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      GroupBox {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text("Notifications")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Spacer()
            Toggle("Enable notifications", isOn: $preferences.notificationsEnabled)
              .labelsHidden()
          }

          if preferences.notificationsEnabled {
            Toggle("Work end notification", isOn: $preferences.workEndNotificationsEnabled)
            Toggle("Break end notification", isOn: $preferences.breakEndNotificationsEnabled)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(embedded ? 10 : 16)
    .onChange(of: preferences.pomodoroMinutes) { _, newValue in
      preferences.pomodoroMinutes = clamp(newValue, min: 1, max: 120)
      let mapped = WorkPreset.from(minutes: preferences.pomodoroMinutes)
      if workPreset != mapped {
        workPreset = mapped
      }
    }
    .onChange(of: preferences.shortBreakMinutes) { _, newValue in
      preferences.shortBreakMinutes = clamp(newValue, min: 1, max: 30)
      let mapped = BreakPreset.from(minutes: preferences.shortBreakMinutes)
      if breakPreset != mapped {
        breakPreset = mapped
      }
    }

    if embedded {
      content
    } else {
      content.frame(width: 360, alignment: .leading)
    }
  }

  private func applyWorkPreset(_ preset: WorkPreset) {
    switch preset {
    case .min25:
      preferences.pomodoroMinutes = 25
    case .min50:
      preferences.pomodoroMinutes = 50
    case .custom:
      if [25, 50].contains(preferences.pomodoroMinutes) {
        preferences.pomodoroMinutes = 30
      }
    }
  }

  private func applyBreakPreset(_ preset: BreakPreset) {
    switch preset {
    case .min5:
      preferences.shortBreakMinutes = 5
    case .min10:
      preferences.shortBreakMinutes = 10
    case .custom:
      if [5, 10].contains(preferences.shortBreakMinutes) {
        preferences.shortBreakMinutes = 7
      }
    }
  }

  private func clamp(_ value: Int, min: Int, max: Int) -> Int {
    Swift.max(min, Swift.min(max, value))
  }
}

private enum WorkPreset: String, CaseIterable, Identifiable {
  case min25
  case min50
  case custom

  var id: String { rawValue }

  var title: String {
    switch self {
    case .min25:
      return "25"
    case .min50:
      return "50"
    case .custom:
      return "Custom"
    }
  }

  static func from(minutes: Int) -> WorkPreset {
    switch minutes {
    case 25:
      return .min25
    case 50:
      return .min50
    default:
      return .custom
    }
  }
}

private enum BreakPreset: String, CaseIterable, Identifiable {
  case min5
  case min10
  case custom

  var id: String { rawValue }

  var title: String {
    switch self {
    case .min5:
      return "5"
    case .min10:
      return "10"
    case .custom:
      return "Custom"
    }
  }

  static func from(minutes: Int) -> BreakPreset {
    switch minutes {
    case 5:
      return .min5
    case 10:
      return .min10
    default:
      return .custom
    }
  }
}
