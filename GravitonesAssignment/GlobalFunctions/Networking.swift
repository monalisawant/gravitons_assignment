//
//  Networking.swift
//  GravitonesAssignment > GlobalFunctions
//
//  Thin networking layer mirroring the reference project: a `serviceUrl` global,
//  a `HeaderManager` singleton that injects the Bearer token from the Keychain,
//  and a `NetworkHelper` that assembles requests.
//

import Foundation

/// Backend base URL. Sourced from the gitignored `Secrets.swift` so it never
/// lands in source control.
let serviceUrl = Secrets.apiBaseURL

/// Errors surfaced by the networking layer, with user-presentable descriptions.
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case rateLimited
    case server(status: Int, message: String?)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The request URL was invalid."
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .unauthorized:
            return "Your session has expired. Please sign in again."
        case .rateLimited:
            return "Too many attempts. Please wait a few minutes and try again."
        case .server(let status, let message):
            return message ?? "Something went wrong (\(status))."
        case .decoding:
            return "Couldn't read the server response."
        }
    }
}

/// Central place that assembles HTTP headers and attaches the auth token,
/// read fresh from the Keychain on every request.
final class HeaderManager {
    static let shared = HeaderManager()
    private init() {}

    func createHeaders(authorized: Bool = true) -> [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]
        if authorized, let accessToken = retrieveFromKeychain(key: .accessToken) {
            headers["Authorization"] = "Bearer \(accessToken)"
        }
        return headers
    }
}

/// Builds `URLRequest`s against `serviceUrl` with the standard headers.
enum NetworkHelper {
    static func createRequest(
        path: String,
        method: String,
        authorized: Bool = true,
        body: Data? = nil
    ) throws -> URLRequest {
        guard let url = URL(string: serviceUrl + path) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.allHTTPHeaderFields = HeaderManager.shared.createHeaders(authorized: authorized)
        return request
    }
}
