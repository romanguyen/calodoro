import SwiftUI

struct TaskInputView: View {
  @ObservedObject var taskViewModel: TaskViewModel
  let onSubmit: (String) -> Void
  @FocusState private var isFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("New Event")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      HStack(spacing: 6) {
        TextField("Event name", text: $taskViewModel.taskName)
          .textFieldStyle(.roundedBorder)
          .focused($isFocused)
          .submitLabel(.done)
          .onSubmit {
            handleSubmit()
          }
          .onExitCommand {
            isFocused = false
          }

        Button("Add") {
          handleSubmit()
        }
        .disabled(!isFocused)
      }
    }
  }

  private func handleSubmit() {
    let trimmed = taskViewModel.taskName.trimmedOrUntitled
    if trimmed != "Untitled Task" {
      onSubmit(trimmed)
      taskViewModel.taskName = ""
    }
    isFocused = false
  }
}
