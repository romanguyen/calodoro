import Foundation

extension String {
  var trimmedOrUntitled: String {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "Untitled Task" : trimmed
  }
}
