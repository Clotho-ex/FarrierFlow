import Foundation
import Security
import Supabase

nonisolated enum SyncSessionKeychainStorageError: Error, Equatable {
    case keychainFailure(OSStatus)
    case corruptData
}

nonisolated struct SyncSessionKeychainStorage: AuthLocalStorage {
    let service: String

    init(service: String = "com.farrierflow.yusufcan.FarrierFlow.sync-session") {
        self.service = service
    }

    func store(key: String, value: Data) throws {
        var attributes = query(key: key)
        attributes[kSecValueData] = value
        attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let update = [
                kSecValueData: value,
                kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            ] as [CFString: Any]
            try requireSuccess(SecItemUpdate(query(key: key) as CFDictionary, update as CFDictionary))
        } else {
            try requireSuccess(status)
        }
    }

    func retrieve(key: String) throws -> Data? {
        var attributes = query(key: key)
        attributes[kSecReturnData] = true
        attributes[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        try requireSuccess(status)
        guard let data = result as? Data else { throw SyncSessionKeychainStorageError.corruptData }
        return data
    }

    func remove(key: String) throws {
        let status = SecItemDelete(query(key: key) as CFDictionary)
        if status != errSecItemNotFound { try requireSuccess(status) }
    }

    private func query(key: String) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword, kSecAttrService: service,
         kSecAttrAccount: key, kSecAttrSynchronizable: false]
    }

    private func requireSuccess(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw SyncSessionKeychainStorageError.keychainFailure(status) }
    }
}
