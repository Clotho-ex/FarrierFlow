import Foundation
import Security
import Testing
@testable import FarrierFlow

@Suite("Device-bound Apple cloud sessions", .serialized)
struct SyncSessionKeychainStorageTests {
    @Test
    func sessionPersistsOnlyOnThisDeviceAndDoesNotSynchronizeThroughKeychain() throws {
        let service = "FarrierFlow.Auth.Tests." + UUID().uuidString
        defer { removeTestNamespace(service) }
        let storage = SyncSessionKeychainStorage(service: service)
        let value = Data("synthetic-session".utf8)
        try storage.store(key: "session", value: value)
        #expect(try SyncSessionKeychainStorage(service: service).retrieve(key: "session") == value)
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword, kSecAttrService: service,
            kSecAttrAccount: "session", kSecReturnAttributes: true,
        ] as CFDictionary, &result)
        #expect(status == errSecSuccess)
        let attributes = try #require(result as? [String: Any])
        #expect(attributes[kSecAttrAccessible as String] as? String ==
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        #expect(attributes[kSecAttrSynchronizable as String] as? Bool != true)
    }

    @Test
    func replacingSessionDoesNotTouchOtherSDKKeysOrNamespaces() throws {
        let service = "FarrierFlow.Auth.Tests." + UUID().uuidString
        defer { removeTestNamespace(service) }
        let storage = SyncSessionKeychainStorage(service: service)
        try storage.store(key: "first", value: Data("old".utf8))
        try storage.store(key: "second", value: Data("keep".utf8))
        try storage.store(key: "first", value: Data("new".utf8))
        #expect(try storage.retrieve(key: "first") == Data("new".utf8))
        #expect(try storage.retrieve(key: "second") == Data("keep".utf8))
        #expect(try SyncSessionKeychainStorage(service: service + ".other").retrieve(key: "first") == nil)
    }

    @Test
    func removingSessionIsIdempotentAndCannotDeleteAnotherKey() throws {
        let service = "FarrierFlow.Auth.Tests." + UUID().uuidString
        defer { removeTestNamespace(service) }
        let storage = SyncSessionKeychainStorage(service: service)
        try storage.store(key: "session", value: Data("remove".utf8))
        try storage.store(key: "other", value: Data("keep".utf8))
        try storage.remove(key: "session")
        try storage.remove(key: "session")
        #expect(try storage.retrieve(key: "session") == nil)
        #expect(try storage.retrieve(key: "other") == Data("keep".utf8))
    }

    private func removeTestNamespace(_ service: String) {
        _ = SecItemDelete([kSecClass: kSecClassGenericPassword, kSecAttrService: service] as CFDictionary)
    }
}
