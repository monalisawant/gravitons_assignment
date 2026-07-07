//
//  AuthViewModel.swift
//  GravitonesAssignment > ViewModel
//
//  Owns authentication state for the app: performs login/logout against the API
//  and persists tokens + user to the Keychain. Session restoration on launch is
//  driven purely by what's already in the Keychain.
//

import Foundation

@MainActor
final class AuthViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case loading
        case error(String)
    }

    @Published private(set) var isAuthenticated: Bool
    @Published private(set) var currentUser: AuthUser?
    @Published var state: State = .idle

    private var sessionExpiredObserver: NSObjectProtocol?

    init() {
        // Restore an existing session from the Keychain on cold launch.
        self.isAuthenticated = retrieveFromKeychain(key: .accessToken) != nil
        self.currentUser = Self.restoreUser()

        // A refresh that can't recover (posted by APIClient) forces sign-in again.
        sessionExpiredObserver = NotificationCenter.default.addObserver(
            forName: .sessionExpired, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSessionExpired() }
        }
    }

    deinit {
        if let sessionExpiredObserver {
            NotificationCenter.default.removeObserver(sessionExpiredObserver)
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !password.isEmpty else {
            state = .error("Please enter your email and password.")
            return
        }

        state = .loading
        do {
            let body = try JSONEncoder().encode(LoginRequest(email: email, password: password))
            let (data, http) = try await APIClient.shared.send(
                path: "/api/auth/login", method: "POST", authorized: false, body: body
            )

            switch http.statusCode {
            case 200:
                let result = try decode(LoginResponse.self, from: data)
                persist(result)
                currentUser = result.user
                isAuthenticated = true
                state = .idle
            case 400, 401:
                state = .error(serverMessage(from: data) ?? "Incorrect email or password.")
            case 429:
                state = .error(APIError.rateLimited.errorDescription ?? "Too many attempts.")
            default:
                state = .error(serverMessage(from: data) ?? "Sign in failed (\(http.statusCode)).")
            }
        } catch let error as APIError {
            state = .error(error.errorDescription ?? "Sign in failed.")
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    // MARK: - Logout

    func logout() async {
        // Best-effort server-side invalidation; the local session is cleared
        // regardless of whether the network call succeeds.
        _ = try? await APIClient.shared.send(path: "/api/auth/logout", method: "POST")
        clearSession()
        state = .idle
    }

    /// Called when APIClient can't refresh an expired session.
    private func handleSessionExpired() {
        guard isAuthenticated else { return }
        clearSession()
        state = .error("Your session has expired. Please sign in again.")
    }

    private func clearSession() {
        clearSessionKeychainValues()
        currentUser = nil
        isAuthenticated = false
    }

    // MARK: - Persistence

    private func persist(_ response: LoginResponse) {
        storeInKeychain(key: .accessToken, value: response.accessToken)
        storeInKeychain(key: .refreshToken, value: response.refreshToken)
        storeInKeychain(key: .userId, value: response.user.id)
        storeInKeychain(key: .userEmail, value: response.user.email)
        storeInKeychain(key: .userName, value: response.user.name)
        storeInKeychain(key: .userRole, value: response.user.role)
    }

    private static func restoreUser() -> AuthUser? {
        guard let id = retrieveFromKeychain(key: .userId),
              let email = retrieveFromKeychain(key: .userEmail),
              let name = retrieveFromKeychain(key: .userName),
              let role = retrieveFromKeychain(key: .userRole) else { return nil }
        return AuthUser(id: id, email: email, name: name, role: role)
    }

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIError.decoding(error) }
    }

    private func serverMessage(from data: Data) -> String? {
        (try? JSONDecoder().decode(APIErrorResponse.self, from: data))?.displayMessage
    }
}
