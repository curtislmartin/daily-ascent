import Foundation
import CryptoKit
import Security

nonisolated enum CommunityIdentity {
    private static let service = "daily-ascent-community-id"
    private static let account = "device_uuid"

    /// Stable anonymous device hash. Generates a Keychain UUID on first call.
    static var deviceHash: String {
        let uuid = readFromKeychain() ?? generateAndStore()
        let hash = SHA256.hash(data: Data(uuid.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Keychain

    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    private static func generateAndStore() -> String {
        let uuid = UUID().uuidString
        let data = Data(uuid.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemAdd(query as CFDictionary, nil)
        return uuid
    }

    /// Removes the Keychain UUID. Used when deleting community data.
    static func deleteIdentity() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
