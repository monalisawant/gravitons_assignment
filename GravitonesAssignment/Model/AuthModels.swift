//
//  AuthModels.swift
//  GravitonesAssignment > Model
//
//  Codable models for the authentication endpoints.
//  The API uses camelCase keys, so no custom CodingKeys are needed.
//

import Foundation

// MARK: - Requests

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

/// Body of `POST /api/auth/refresh`.
struct RefreshRequest: Encodable {
    let refreshToken: String
}

// MARK: - Responses

/// The authenticated user returned by `POST /api/auth/login`.
struct AuthUser: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let name: String
    let role: String
}

/// Body of a successful `POST /api/auth/login` (200).
struct LoginResponse: Decodable {
    let user: AuthUser
    let accessToken: String
    let refreshToken: String
}

/// Body of a successful `POST /api/auth/refresh` (200). Both tokens rotate.
struct RefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

/// Best-effort decode of an error body so we can surface a server-provided message.
struct APIErrorResponse: Decodable {
    let message: String?
    let error: String?

    var displayMessage: String? { message ?? error }
}
