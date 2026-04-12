import Foundation
import Security

final class APIKeyStore: ObservableObject {
    private let serviceName = "com.flowkeys.app.keys"

    func saveKey(_ key: String, for provider: TranscriptionProvider) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteKey(for: provider)
            return
        }

        let account = accountName(for: provider)
        guard let encoded = trimmed.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: encoded,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = encoded
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }

        objectWillChange.send()
    }

    func getKey(for provider: TranscriptionProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName(for: provider),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return value
    }

    func deleteKey(for provider: TranscriptionProvider) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName(for: provider)
        ]
        SecItemDelete(query as CFDictionary)
        objectWillChange.send()
    }

    func hasKey(for provider: TranscriptionProvider) -> Bool {
        getKey(for: provider) != nil
    }

    func maskedKey(for provider: TranscriptionProvider) -> String {
        guard let key = getKey(for: provider) else { return "" }
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 8 else { return "••••••••" }
        let prefix = String(trimmed.prefix(4))
        let suffix = String(trimmed.suffix(4))
        return "\(prefix)...\(suffix)"
    }

    private func accountName(for provider: TranscriptionProvider) -> String {
        "provider_\(provider.rawValue)_api_key"
    }
}
