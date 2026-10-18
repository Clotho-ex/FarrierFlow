import Foundation
import Security

nonisolated enum SyncDeviceIdentityError: Error, Equatable {
    case corruptIdentity
    case keychainFailure(OSStatus)
}

nonisolated enum SyncDeviceIdentity {
    static func loadOrCreate(
        service: String = "com.farrierflow.yusufcan.FarrierFlow.sync-device"
    ) throws -> UUID {
        if let existing = try read(service: service) { return existing }
        let id = UUID()
        var attributes = query(service: service)
        attributes[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        attributes[kSecAttrSynchronizable] = false
        attributes[kSecValueData] = Data(id.uuidString.utf8)
        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            guard let existing = try read(service: service) else {
                throw SyncDeviceIdentityError.keychainFailure(errSecItemNotFound)
            }
            return existing
        }
        guard status == errSecSuccess else {
            throw SyncDeviceIdentityError.keychainFailure(status)
        }
        return id
    }

    private static func read(service: String) throws -> UUID? {
        var attributes = query(service: service)
        attributes[kSecReturnData] = true
        attributes[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw SyncDeviceIdentityError.keychainFailure(status)
        }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8),
              let id = UUID(uuidString: value) else {
            throw SyncDeviceIdentityError.corruptIdentity
        }
        return id
    }

    private static func query(service: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "device-id",
            kSecAttrSynchronizable: false,
        ]
    }
}
