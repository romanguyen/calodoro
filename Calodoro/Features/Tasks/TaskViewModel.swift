import Foundation

@MainActor
final class TaskViewModel: ObservableObject {
  @Published var taskName: String = ""
}
