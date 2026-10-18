import Foundation
import Security
import Testing
@testable import FarrierFlow

@Suite("Device-bound sync identity", .serialized)
struct SyncDeviceIdentityTests {
    @Test
    func reopeningUsesSameDeviceIdentityWithoutCloudKeychainSync() throws {
        let service = "FarrierFlow.SyncDevice.Tests." + UUID().uuidString
        defer { deleteTestItem(service: service) }
        let first = try SyncDeviceIdentity.loadOrCreate(service: service)
        let second = try SyncDeviceIdentity.loadOrCreate(service: service)
        #expect(first == second)
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "device-id",
            kSecReturnAttributes: true,
        ] as CFDictionary, &result)
        #expect(status == errSecSuccess)
        let attributes = try #require(result as? [String: Any])
        #expect(attributes[kSecAttrAccessible as String] as? String ==
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        #expect(attributes[kSecAttrSynchronizable as String] as? Bool != true)
    }

    @Test
    func corruptStoredIdentityDoesNotSilentlyBecomeAnInvoicingDevice() throws {
        let service = "FarrierFlow.SyncDevice.Tests." + UUID().uuidString
        defer { deleteTestItem(service: service) }
        let status = SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "device-id",
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData: Data("not-a-device-uuid".utf8),
        ] as CFDictionary, nil)
        #expect(status == errSecSuccess)
        #expect(throws: SyncDeviceIdentityError.corruptIdentity) {
            try SyncDeviceIdentity.loadOrCreate(service: service)
        }
    }

    private func deleteTestItem(service: String) {
        _ = SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "device-id",
        ] as CFDictionary)
    }
}
