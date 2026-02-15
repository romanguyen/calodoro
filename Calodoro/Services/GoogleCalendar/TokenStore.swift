import Foundation

struct StoredToken: Codable {
  let accessToken: String
  let refreshToken: String?
  let expiresAt: Date
}

struct TokenStore {
  private let defaults = UserDefaults.standard
  private let tokenKey = "googleToken"

  func load() -> StoredToken? {
    guard let data = defaults.data(forKey: tokenKey) else {
      return nil
    }
    return try? JSONDecoder().decode(StoredToken.self, from: data)
  }

  func save(_ token: StoredToken) {
    guard let data = try? JSONEncoder().encode(token) else {
      return
    }
    defaults.set(data, forKey: tokenKey)
  }

  func clear() {
    defaults.removeObject(forKey: tokenKey)
  }
}
