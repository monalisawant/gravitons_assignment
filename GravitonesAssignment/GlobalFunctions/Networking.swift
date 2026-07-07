//
//  Networking.swift
//  GravitonesAssignment
//

import Foundation

// Base URL comes from the gitignored Secrets.swift so it stays out of git.
let serviceUrl = Secrets.apiBaseURL

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

// Builds the standard headers and attaches the Bearer token, read fresh from
// the Keychain each time.
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
