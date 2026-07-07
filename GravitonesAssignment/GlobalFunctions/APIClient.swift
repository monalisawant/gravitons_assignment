//
//  APIClient.swift
//  GravitonesAssignment
//
//  One place every request goes through. On a 401 it refreshes the access token
//  and retries once. Refreshes are single-flighted so a burst of 401s only hits
//  /api/auth/refresh once (and rotates the refresh token once).
//

import Foundation

extension Notification.Name {
    // Posted when the refresh token is also dead and the user must sign in again.
    static let sessionExpired = Notification.Name("com.gravitons.sessionExpired")
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let refresher: TokenRefresher

    init(session: URLSession = .shared) {
        self.session = session
        self.refresher = TokenRefresher(session: session)
    }

    @discardableResult
    func send(
        path: String,
        method: String,
        authorized: Bool = true,
        body: Data? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        var result = try await perform(path: path, method: method, authorized: authorized, body: body)

        guard authorized, result.1.statusCode == 401 else { return result }

        // Access token likely expired — refresh once and retry the original request.
        if await refresher.refresh() {
            result = try await perform(path: path, method: method, authorized: true, body: body)
        }

        if result.1.statusCode == 401 {
            await MainActor.run { NotificationCenter.default.post(name: .sessionExpired, object: nil) }
            throw APIError.unauthorized
        }
        return result
    }

    private func perform(
        path: String,
        method: String,
        authorized: Bool,
        body: Data?
    ) async throws -> (Data, HTTPURLResponse) {
        let request = try NetworkHelper.createRequest(path: path, method: method, authorized: authorized, body: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        return (data, http)
    }
}

// Makes sure only one refresh runs at a time.
private actor TokenRefresher {
    private let session: URLSession
    private var inFlight: Task<Bool, Never>?

    init(session: URLSession) {
        self.session = session
    }

    // Callers that arrive mid-refresh wait on the same task.
    func refresh() async -> Bool {
        if let inFlight { return await inFlight.value }

        let task = Task { [session] in await TokenRefresher.performRefresh(using: session) }
        inFlight = task
        let succeeded = await task.value
        inFlight = nil
        return succeeded
    }

    private static func performRefresh(using session: URLSession) async -> Bool {
        guard let refreshToken = retrieveFromKeychain(key: .refreshToken) else { return false }
        do {
            let body = try JSONEncoder().encode(RefreshRequest(refreshToken: refreshToken))
            let request = try NetworkHelper.createRequest(
                path: "/api/auth/refresh", method: "POST", authorized: false, body: body
            )
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }

            let result = try JSONDecoder().decode(RefreshResponse.self, from: data)
            // Refresh tokens rotate — persist the new one, not just the access token.
            storeInKeychain(key: .accessToken, value: result.accessToken)
            storeInKeychain(key: .refreshToken, value: result.refreshToken)
            return true
        } catch {
            return false
        }
    }
}
