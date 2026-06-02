/*
 KeychainStore.swift
 ===================

 Minimal wrapper over the macOS Keychain for storing small secrets
 (the Gemini API key). Never logged, never written to UserDefaults or disk.
 */

import Foundation
import Security

enum KeychainStore {
    /// Service namespace for this app's Keychain items.
    private static let service = "com.aitranscribe.AiTranscribe"

    /// Read a secret string for the given account, or nil if absent.
    static func get(_ account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    /// Store (or update) a secret string. Passing an empty string deletes it.
    @discardableResult
    static func set(_ value: String, for account: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return delete(account)
        }

        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let data = Data(trimmed.utf8)

        // Try update first; if not found, add.
        let updateStatus = SecItemUpdate(base as CFDictionary,
                                         [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    @discardableResult
    static func delete(_ account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
