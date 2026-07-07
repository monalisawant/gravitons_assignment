//
//  AuthModels.swift
//  GravitonesAssignment
//

import Foundation

// MARK: - Requests

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

struct RefreshRequest: Encodable {
    let refreshToken: String
}

// MARK: - Responses

struct AuthUser: Codable, Identifiable, Equatable {
    let id: String
    let email: String
    let name: String
    let role: String
}

struct LoginResponse: Decodable {
    let user: AuthUser
    let accessToken: String
    let refreshToken: String
}

struct RefreshResponse: Decodable {
    let accessToken: String
    let refreshToken: String
}

// Used to pull a message out of an error response body.
struct APIErrorResponse: Decodable {
    let message: String?
    let error: String?

    var displayMessage: String? { message ?? error }
}
