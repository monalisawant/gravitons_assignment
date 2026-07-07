//
//  APIClient.swift
//  GravitonesAssignment > GlobalFunctions
//
//  Single entry point for HTTP requests. Transparently refreshes the access
//  token on a 401 and retries the original request once. Refreshes are
//  single-flighted via an actor, so a burst of concurrent 401s triggers only
//  one call to /api/auth/refresh (and only one rotation of the refresh token).
//

import Foundation

extension Notification.Name {
    /// Posted when the session can no longer be refreshed and the user must sign in again.
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

    /// Sends a request and returns its data + HTTP response. For authorized
    /// requests, a 401 triggers a token refresh and a single retry; if that
    /// still fails, `.sessionExpired` is posted and `APIError.unauthorized`
    /// is thrown.
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

/// Coordinates access-token refresh so at most one refresh runs at a time.
private actor TokenRefresher {
    private let session: URLSession
    private var inFlight: Task<Bool, Never>?

    init(session: URLSession) {
        self.session = session
    }

    /// Returns `true` if the access token was refreshed and re-stored. Callers
    /// that arrive while a refresh is already running await the same result.
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
