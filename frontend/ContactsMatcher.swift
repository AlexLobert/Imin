import Contacts
import CryptoKit
import Foundation

enum ContactsMatcher {
    static func requestAccess() async -> Bool {
        let store = CNContactStore()
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }

    static func loadHashedIdentifiers() throws -> [String] {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        var hashes = Set<String>()

        try store.enumerateContacts(with: request) { contact, _ in
            for email in contact.emailAddresses {
                let normalized = normalizeEmail(email.value as String)
                if let hash = sha256Hex(normalized) {
                    hashes.insert(hash)
                }
            }

            for phone in contact.phoneNumbers {
                let normalized = normalizePhone(phone.value.stringValue)
                if let hash = sha256Hex(normalized) {
                    hashes.insert(hash)
                }
            }
        }

        return Array(hashes)
    }

    private static func normalizeEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizePhone(_ value: String) -> String {
        let digits = value.filter { $0.isNumber }
        return digits
    }

    private static func sha256Hex(_ value: String) -> String? {
        guard !value.isEmpty else { return nil }
        let data = Data(value.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
