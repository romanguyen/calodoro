import Foundation
import AuthenticationServices
import CryptoKit
import AppKit
import Security

@MainActor
final class GoogleAuthService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
  enum AuthStatus {
    case signedOut
    case signedIn
  }

  enum AuthError: Error {
    case missingConfiguration
    case invalidCallback
    case missingAuthCode
    case userCanceled
    case notAuthenticated
    case tokenRefreshFailed
    case oauthError(String)
    case tokenExchangeFailed(String)
  }

  @Published private(set) var status: AuthStatus = .signedOut

  private let clientId: String
  private let redirectScheme: String
  private let clientSecret: String?
  private let tokenStore = TokenStore()

  private var currentSession: ASWebAuthenticationSession?

  private var redirectUri: String {
    "\(redirectScheme):/oauth2redirect"
  }

  override init() {
    let clientId = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String ?? ""
    let redirectScheme = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_REDIRECT_SCHEME") as? String ?? ""
    let clientSecret = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_CLIENT_SECRET") as? String

    self.clientId = clientId
    self.redirectScheme = redirectScheme
    if let clientSecret, !clientSecret.isEmpty {
      self.clientSecret = clientSecret
    } else {
      self.clientSecret = nil
    }

    super.init()
    status = tokenStore.load() == nil ? .signedOut : .signedIn
  }

  func signIn() async throws {
    guard !clientId.isEmpty, !redirectScheme.isEmpty else {
      throw AuthError.missingConfiguration
    }
    let verifier = PKCE.codeVerifier()
    let challenge = PKCE.codeChallenge(for: verifier)
    let authURL = authorizationURL(codeChallenge: challenge)

    let callbackURL = try await startAuthSession(authURL: authURL)
    if let errorValue = Self.extractQueryValue(from: callbackURL, name: "error") {
      throw AuthError.oauthError(errorValue)
    }
    guard let code = Self.extractQueryValue(from: callbackURL, name: "code") else {
      throw AuthError.missingAuthCode
    }

    let token = try await exchangeCodeForToken(code: code, verifier: verifier)
    tokenStore.save(token)
    status = .signedIn
  }

  func signOut() {
    tokenStore.clear()
    status = .signedOut
  }

  func validAccessToken() async throws -> String {
    guard var token = tokenStore.load() else {
      throw AuthError.notAuthenticated
    }

    if token.expiresAt > Date() {
      return token.accessToken
    }

    guard let refreshToken = token.refreshToken else {
      signOut()
      throw AuthError.notAuthenticated
    }

    token = try await refreshAccessToken(refreshToken: refreshToken, existingRefreshToken: refreshToken)
    tokenStore.save(token)
    status = .signedIn
    return token.accessToken
  }

  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    NSApp.keyWindow ?? NSApp.windows.first ?? ASPresentationAnchor()
  }

  private func authorizationURL(codeChallenge: String) -> URL {
    var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")
    components?.queryItems = [
      URLQueryItem(name: "client_id", value: clientId),
      URLQueryItem(name: "redirect_uri", value: redirectUri),
      URLQueryItem(name: "response_type", value: "code"),
      URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
      URLQueryItem(name: "code_challenge", value: codeChallenge),
      URLQueryItem(name: "code_challenge_method", value: "S256"),
      URLQueryItem(name: "access_type", value: "offline"),
      URLQueryItem(name: "prompt", value: "consent"),
      URLQueryItem(name: "include_granted_scopes", value: "true")
    ]

    return components?.url ?? URL(string: "https://accounts.google.com")!
  }

  private func startAuthSession(authURL: URL) async throws -> URL {
    try await withCheckedThrowingContinuation { continuation in
      let session = ASWebAuthenticationSession(
        url: authURL,
        callbackURLScheme: redirectScheme
      ) { [weak self] url, error in
        self?.currentSession = nil
        if let error = error as? ASWebAuthenticationSessionError,
           error.code == .canceledLogin {
          continuation.resume(throwing: AuthError.userCanceled)
          return
        }

        if let error = error {
          continuation.resume(throwing: error)
          return
        }

        guard let url = url else {
          continuation.resume(throwing: AuthError.invalidCallback)
          return
        }

        continuation.resume(returning: url)
      }

      session.presentationContextProvider = self
      session.prefersEphemeralWebBrowserSession = true
      self.currentSession = session
      session.start()
    }
  }

  private func exchangeCodeForToken(code: String, verifier: String) async throws -> StoredToken {
    let url = URL(string: "https://oauth2.googleapis.com/token")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    var parameters: [String: String] = [
      "client_id": clientId,
      "code": code,
      "code_verifier": verifier,
      "redirect_uri": redirectUri,
      "grant_type": "authorization_code"
    ]
    if let clientSecret {
      parameters["client_secret"] = clientSecret
    }

    let body = formURLEncoded(parameters)
    request.httpBody = body

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw AuthError.invalidCallback
    }

    guard httpResponse.statusCode == 200 else {
      let reason = decodeTokenError(from: data) ?? "HTTP \(httpResponse.statusCode)"
      throw AuthError.tokenExchangeFailed(reason)
    }

    let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
    let expiresAt = Date().addingTimeInterval(TimeInterval(max(0, tokenResponse.expires_in - 60)))
    return StoredToken(
      accessToken: tokenResponse.access_token,
      refreshToken: tokenResponse.refresh_token,
      expiresAt: expiresAt
    )
  }

  private func refreshAccessToken(refreshToken: String, existingRefreshToken: String) async throws -> StoredToken {
    let url = URL(string: "https://oauth2.googleapis.com/token")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    var parameters: [String: String] = [
      "client_id": clientId,
      "refresh_token": refreshToken,
      "grant_type": "refresh_token"
    ]
    if let clientSecret {
      parameters["client_secret"] = clientSecret
    }

    let body = formURLEncoded(parameters)
    request.httpBody = body

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw AuthError.tokenRefreshFailed
    }

    guard httpResponse.statusCode == 200 else {
      throw AuthError.tokenRefreshFailed
    }

    let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
    let expiresAt = Date().addingTimeInterval(TimeInterval(max(0, tokenResponse.expires_in - 60)))
    return StoredToken(
      accessToken: tokenResponse.access_token,
      refreshToken: tokenResponse.refresh_token ?? existingRefreshToken,
      expiresAt: expiresAt
    )
  }

  private func formURLEncoded(_ parameters: [String: String]) -> Data {
    let body = parameters
      .map { key, value in
        let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
        let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
        return "\(escapedKey)=\(escapedValue)"
      }
      .joined(separator: "&")

    return Data(body.utf8)
  }

  private static func extractQueryValue(from url: URL, name: String) -> String? {
    let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
    return components?.queryItems?.first { $0.name == name }?.value
  }

  private func decodeTokenError(from data: Data) -> String? {
    guard let errorResponse = try? JSONDecoder().decode(TokenErrorResponse.self, from: data) else {
      return nil
    }
    if let description = errorResponse.error_description {
      return "\(errorResponse.error): \(description)"
    }
    return errorResponse.error
  }

  private var scopes: [String] {
    [
      "https://www.googleapis.com/auth/calendar.readonly",
      "https://www.googleapis.com/auth/calendar.events"
    ]
  }
}

extension GoogleAuthService.AuthError: LocalizedError {
  var errorDescription: String? {
    switch self {
    case .missingConfiguration:
      return "Missing Google OAuth configuration"
    case .invalidCallback:
      return "Invalid auth callback"
    case .missingAuthCode:
      return "Missing authorization code"
    case .userCanceled:
      return "Sign-in canceled"
    case .notAuthenticated:
      return "Not authenticated"
    case .tokenRefreshFailed:
      return "Token refresh failed"
    case .oauthError(let message):
      return "OAuth error: \(message)"
    case .tokenExchangeFailed(let reason):
      return "Token exchange failed: \(reason)"
    }
  }
}

private enum PKCE {
  static func codeVerifier() -> String {
    var data = Data(count: 32)
    _ = data.withUnsafeMutableBytes { bytes in
      SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
    }
    return base64URLEncode(data)
  }

  static func codeChallenge(for verifier: String) -> String {
    let data = Data(verifier.utf8)
    let hash = SHA256.hash(data: data)
    return base64URLEncode(Data(hash))
  }

  private static func base64URLEncode(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}

private struct TokenResponse: Decodable {
  let access_token: String
  let refresh_token: String?
  let expires_in: Int
}

private struct TokenErrorResponse: Decodable {
  let error: String
  let error_description: String?
}
