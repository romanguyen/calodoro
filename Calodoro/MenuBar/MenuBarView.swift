import SwiftUI
import AppKit

struct MenuBarView: View {
  @ObservedObject var timerViewModel: TimerViewModel
  @ObservedObject var taskViewModel: TaskViewModel
  @ObservedObject var calendarViewModel: CalendarViewModel
  let notificationService: NotificationService
  @ObservedObject var authService: GoogleAuthService
  @ObservedObject var preferences: PreferencesStore
  @State private var authErrorMessage: String? = nil
  @State private var selectedTab: MenuTab = .timer

  private var selectedEventTitle: String? {
    guard let selectedEventId = calendarViewModel.selectedEventId else {
      return nil
    }
    return calendarViewModel.events.first { $0.id == selectedEventId }?.title
  }

  private var selectedEventIsAllDay: Bool {
    guard let selectedEventId = calendarViewModel.selectedEventId else {
      return false
    }
    return calendarViewModel.events.first { $0.id == selectedEventId }?.isAllDay ?? false
  }


  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Picker("Tab", selection: $selectedTab) {
        ForEach(MenuTab.allCases) { tab in
          Label(tab.title, systemImage: tab.systemImage).tag(tab)
        }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
      .frame(maxWidth: .infinity)
      switch selectedTab {
      case .timer:
        TimerTabView(
          timerViewModel: timerViewModel,
          taskViewModel: taskViewModel,
          calendarViewModel: calendarViewModel,
          notificationService: notificationService,
          authService: authService,
          selectedEventTitle: selectedEventTitle,
          selectedEventIsAllDay: selectedEventIsAllDay
        )
      case .settings:
        SettingsTabView(
          preferences: preferences,
          authService: authService,
          calendarViewModel: calendarViewModel,
          authErrorMessage: $authErrorMessage
        )
      }
    }
    .padding(.horizontal, 12)
    .padding(.top, 6)
    .padding(.bottom, 10)
    .frame(width: 320)
  }
}

private enum MenuTab: String, CaseIterable, Identifiable {
  case timer
  case settings

  var id: String { rawValue }

  var title: String {
    switch self {
    case .timer:
      return "Timer"
    case .settings:
      return "Settings"
    }
  }

  var systemImage: String {
    switch self {
    case .timer:
      return "timer"
    case .settings:
      return "gearshape"
    }
  }
}

private struct TimerStatusView: View {
  @ObservedObject var timerViewModel: TimerViewModel

  var body: some View {
    HStack {
      Spacer()
      Text(timerViewModel.formattedDisplay)
        .font(.system(size: 32, weight: .semibold, design: .rounded))
        .monospacedDigit()
      Spacer()
    }
  }
}

private struct TimerTabView: View {
  @ObservedObject var timerViewModel: TimerViewModel
  @ObservedObject var taskViewModel: TaskViewModel
  @ObservedObject var calendarViewModel: CalendarViewModel
  let notificationService: NotificationService
  @ObservedObject var authService: GoogleAuthService
  let selectedEventTitle: String?
  let selectedEventIsAllDay: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      TimerStatusView(timerViewModel: timerViewModel)

      HStack(spacing: 8) {
        Spacer()
        Button(timerViewModel.state == .paused ? "Resume" : "Start") {
          if timerViewModel.state == .paused {
            timerViewModel.resume()
          } else {
            let title = selectedEventTitle ?? taskViewModel.taskName.trimmedOrUntitled
            timerViewModel.start(
              taskTitle: title,
              existingEventId: calendarViewModel.selectedEventId,
              existingEventIsAllDay: selectedEventIsAllDay
            )
          }
        }
        .disabled(timerViewModel.state == .running)

        Button("Pause") {
          timerViewModel.pause()
        }
        .disabled(timerViewModel.state != .running)

        Button("Stop") {
          timerViewModel.stop()
        }
        .disabled(timerViewModel.state == .idle)
        Spacer()
      }

        HStack {
          Text("Mode")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
          Picker("Mode", selection: $timerViewModel.mode) {
            ForEach(TimerMode.allCases) { mode in
              Text(mode.title).tag(mode)
            }
          }
          .pickerStyle(.menu)
          .labelsHidden()
          .disabled(timerViewModel.state != .idle)
        }
        
      TaskInputView(taskViewModel: taskViewModel) { title in
        guard authService.status != .signedOut else {
          calendarViewModel.errorMessage = "Sign in to create events"
          return
        }

        Task {
          await calendarViewModel.createAllDayEvent(title: title)
        }
      }

      HStack {
        EventPickerView(calendarViewModel: calendarViewModel)
          .disabled(authService.status == .signedOut)

        Spacer()

        Button("Refresh") {
          Task {
            await calendarViewModel.refresh()
          }
        }
        .disabled(authService.status == .signedOut)
      }

      if let selectedEventTitle {
        Text("Using event: \(selectedEventTitle)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if let calendarSyncMessage = timerViewModel.calendarSyncMessage {
        Text(calendarSyncMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }

      Divider()

      Button("Quit Calodoro") {
        NSApplication.shared.terminate(nil)
      }
    }
    .padding(.horizontal, 6)
    .task {
      await calendarViewModel.refresh()
      await notificationService.requestAuthorization()
    }
  }
}

private struct SettingsTabView: View {
  @ObservedObject var preferences: PreferencesStore
  @ObservedObject var authService: GoogleAuthService
  @ObservedObject var calendarViewModel: CalendarViewModel
  @Binding var authErrorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      GroupBox(label: EmptyView()) {
        GoogleAuthView(
          authService: authService,
          calendarViewModel: calendarViewModel,
          errorMessage: $authErrorMessage
        )
      }
      .padding(.horizontal, 6)
      PreferencesView(preferences: preferences, embedded: true)
    }
  }
}

private struct GoogleAuthView: View {
  @ObservedObject var authService: GoogleAuthService
  @ObservedObject var calendarViewModel: CalendarViewModel
  @Binding var errorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text(authService.status == .signedOut ? "Status: Signed out" : "Status: Signed in")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
        if authService.status == .signedOut {
          Button("Sign in") {
            Task {
              do {
                try await authService.signIn()
                await calendarViewModel.refresh()
                errorMessage = nil
              } catch {
                errorMessage = error.localizedDescription
              }
            }
          }
        } else {
          Button("Sign out") {
            authService.signOut()
            calendarViewModel.clearEvents()
          }
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 2)

      if let errorMessage {
        Text(errorMessage)
          .font(.caption)
          .foregroundStyle(.red)
      }
    }
    .padding(.vertical, 4)
  }
}
