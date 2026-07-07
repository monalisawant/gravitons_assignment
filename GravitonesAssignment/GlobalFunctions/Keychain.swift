//
//  Keychain.swift
//  GravitonesAssignment
//
//  Token storage on top of the Security framework (kSecClassGenericPassword),
//  exposed as small global helpers with a typed key enum so we don't pass raw
//  strings around.
//

import Foundation
import Security

enum KeychainKey: String, CaseIterable {
    case accessToken
    case refreshToken
    case userId
    case userEmail
    case userName
    case userRole
}

// Keys cleared on logout.
let sessionKeychainKeys: [KeychainKey] = KeychainKey.allCases

// Prefix keys in debug builds so a dev session doesn't clobber a release one.
private func prefixedKey(_ key: String) -> String {
    #if DEBUG
    return "dev_\(key)"
    #else
    return key
    #endif
}

// MARK: - Core (string-keyed) API

@discardableResult
func storeInKeychain(key: String, value: String) -> Bool {
    guard !key.isEmpty, !value.isEmpty, let data = value.data(using: .utf8) else { return false }

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: prefixedKey(key)
    ]

    if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
        let attributes: [String: Any] = [kSecValueData as String: data]
        return SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecSuccess
    } else {
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }
}

func retrieveFromKeychain(key: String) -> String? {
    guard !key.isEmpty else { return nil }

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: prefixedKey(key),
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var result: AnyObject?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data,
          let value = String(data: data, encoding: .utf8) else { return nil }
    return value
}

@discardableResult
func deleteFromKeychain(key: String) -> Bool {
    guard !key.isEmpty else { return false }

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: prefixedKey(key)
    ]
    let status = SecItemDelete(query as CFDictionary)
    return status == errSecSuccess || status == errSecItemNotFound
}

// MARK: - Typed convenience API

@discardableResult
func storeInKeychain(key: KeychainKey, value: String) -> Bool {
    storeInKeychain(key: key.rawValue, value: value)
}

func retrieveFromKeychain(key: KeychainKey) -> String? {
    retrieveFromKeychain(key: key.rawValue)
}

@discardableResult
func deleteFromKeychain(key: KeychainKey) -> Bool {
    deleteFromKeychain(key: key.rawValue)
}

func clearSessionKeychainValues() {
    sessionKeychainKeys.forEach { deleteFromKeychain(key: $0) }
}
