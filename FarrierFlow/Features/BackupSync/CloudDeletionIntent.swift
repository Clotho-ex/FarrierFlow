import Foundation
import Supabase

nonisolated enum CloudDeletionError: Error, Equatable {
    case invalidResponse, invalidCredentials, invalidPhase, requestMayHaveBeenSent, receiptNotStored, unavailable
}

nonisolated enum CloudDeletionPhase: Int, Codable, Sendable {
    case prepared, sent, queued, complete
}

nonisolated struct CloudDeletionIntent: Codable, Equatable, Sendable {
    let version: Int
    let accountID: UUID
    let workspaceID: UUID
    let operationID: UUID
    let receiptToken: String
    var phase: CloudDeletionPhase

    init(accountID: UUID, workspaceID: UUID) throws {
        version = 1
        self.accountID = accountID
        self.workspaceID = workspaceID
        operationID = UUID()
        // A separate 32-byte value, never the Apple request's nonce.
        receiptToken = try AppleSignInChallenge().rawNonce
        phase = .prepared
    }

    var isValid: Bool {
        guard version == 1, receiptToken.utf8.count == 43,
              receiptToken.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) ||
                  (48...57).contains($0) || $0 == 45 || $0 == 95 }),
              let data = Data(base64Encoded: receiptToken.replacingOccurrences(of: "-", with: "+")
                  .replacingOccurrences(of: "_", with: "/") + "="), data.count == 32 else { return false }
        return data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") == receiptToken
    }

    func hasSameIdentity(as other: Self) -> Bool {
        version == other.version && accountID == other.accountID && workspaceID == other.workspaceID &&
            operationID == other.operationID && receiptToken == other.receiptToken
    }
}

nonisolated struct CloudDeletionReceiptStore: Sendable {
    static let storageKey = "solo-deletion-receipt-v1"
    let storage: any AuthLocalStorage

    init(storage: any AuthLocalStorage = SyncSessionKeychainStorage(service: "com.farrierflow.yusufcan.FarrierFlow.cloud-deletion")) {
        self.storage = storage
    }
    func load() throws -> CloudDeletionIntent? {
        guard let data = try storage.retrieve(key: Self.storageKey) else { return nil }
        let intent: CloudDeletionIntent
        do { intent = try JSONDecoder().decode(CloudDeletionIntent.self, from: data) }
        catch { throw CloudDeletionError.invalidResponse }
        guard intent.isValid else { throw CloudDeletionError.invalidResponse }
        return intent
    }
    func prepare(accountID: UUID, workspaceID: UUID) throws -> CloudDeletionIntent {
        if let existing = try load() {
            guard existing.accountID == accountID, existing.workspaceID == workspaceID else { throw SyncJournalError.accountMismatch }
            return existing
        }
        let intent = try CloudDeletionIntent(accountID: accountID, workspaceID: workspaceID)
        try save(intent)
        return intent
    }
    func advance(_ intent: CloudDeletionIntent, to phase: CloudDeletionPhase) throws {
        guard var stored = try load(), stored.hasSameIdentity(as: intent) else { throw CloudDeletionError.invalidResponse }
        guard phase.rawValue >= stored.phase.rawValue else { throw CloudDeletionError.invalidPhase }
        stored.phase = phase
        try save(stored)
    }
    func cancelPrepared(_ intent: CloudDeletionIntent) throws {
        guard let stored = try load(), stored.hasSameIdentity(as: intent) else { throw CloudDeletionError.invalidResponse }
        guard stored.phase == .prepared else { throw CloudDeletionError.requestMayHaveBeenSent }
        try storage.remove(key: Self.storageKey)
        guard try storage.retrieve(key: Self.storageKey) == nil else { throw CloudDeletionError.receiptNotStored }
    }
    func retireCompleted(_ intent: CloudDeletionIntent) throws {
        guard let stored = try load(), stored.hasSameIdentity(as: intent), stored.phase == .complete else {
            throw CloudDeletionError.invalidPhase
        }
        try storage.remove(key: Self.storageKey)
        guard try storage.retrieve(key: Self.storageKey) == nil else { throw CloudDeletionError.receiptNotStored }
    }
    private func save(_ intent: CloudDeletionIntent) throws {
        let data = try JSONEncoder().encode(intent)
        try storage.store(key: Self.storageKey, value: data)
        guard try storage.retrieve(key: Self.storageKey) == data else { throw CloudDeletionError.receiptNotStored }
    }
}
