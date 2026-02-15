import Foundation
import SwiftData

@Model
final class TaskItem {
  var id: UUID
  var name: String
  var createdAt: Date
  var lastUsedAt: Date

  init(
    id: UUID = UUID(),
    name: String,
    createdAt: Date = Date(),
    lastUsedAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.createdAt = createdAt
    self.lastUsedAt = lastUsedAt
  }
}
