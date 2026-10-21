import Foundation
import Supabase

nonisolated enum SyncTransportError: Error, Equatable {
    case invalidResponse
    case revisionConflict
    case invoicingDeviceRejected
    case unsupportedOperation
    case confirmedRejection(SyncPushRejectionReason)
    case updateRequired(Int)
}

nonisolated struct SyncWorkspaceInfo: Codable, Equatable, Sendable {
    let workspaceID: UUID
    let deviceID: UUID
    let invoicingDeviceID: UUID?
    let invoicingGeneration: Int64
    let revision: Int64
    var minimumProtocolVersion: Int? = nil
}

nonisolated struct SyncPushReceipt: Codable, Equatable, Sendable {
    let operationID: UUID
    let revision: Int64
}

nonisolated struct SyncInvoiceTakeoverReceipt: Codable, Equatable, Sendable {
    let invoicingDeviceID: UUID
    let invoicingGeneration: Int64
    let revision: Int64
}

nonisolated struct SyncPullPage: Codable, Equatable, Sendable {
    let workspaceID: UUID
    let cursor: Int64
    let hasMore: Bool
    let transactions: [SyncRemoteTransaction]
    let invoicingDeviceID: UUID?
    let invoicingGeneration: Int64
}

nonisolated protocol SyncTransport: Sendable {
    func bootstrap(deviceID: UUID) async throws -> SyncWorkspaceInfo
    func push(_ batch: SyncBatch) async throws -> SyncPushReceipt
    func push(_ batch: SyncBatch, protocolVersion: SyncProtocolVersion) async throws -> SyncPushReceipt
    func pull(workspaceID: UUID, cursor: Int64) async throws -> SyncPullPage
    func pull(workspaceID: UUID, cursor: Int64, protocolVersion: SyncProtocolVersion) async throws -> SyncPullPage
    func takeOverInvoicing(workspaceID: UUID, deviceID: UUID, generation: Int64) async throws -> SyncInvoiceTakeoverReceipt
}

extension SyncTransport {
    func push(_ batch: SyncBatch, protocolVersion: SyncProtocolVersion) async throws -> SyncPushReceipt {
        try await push(batch)
    }
    func pull(workspaceID: UUID, cursor: Int64, protocolVersion: SyncProtocolVersion) async throws -> SyncPullPage {
        try await pull(workspaceID: workspaceID, cursor: cursor)
    }
    func takeOverInvoicing(workspaceID: UUID, deviceID: UUID, generation: Int64) async throws -> SyncInvoiceTakeoverReceipt {
        throw SyncTransportError.unsupportedOperation
    }
}

/// Supabase owns session refresh and authenticated requests. A response is not
/// allowed to advance the journal until its identity and commit order agree.
nonisolated struct SupabaseSyncTransport: SyncTransport {
    let client: SupabaseClient

    func bootstrap(deviceID: UUID) async throws -> SyncWorkspaceInfo {
        let info: SyncWorkspaceInfo = try await client
            .rpc("ff_sync_bootstrap_v2", params: BootstrapParameters(p_device: deviceID))
            .execute().value
        guard info.deviceID == deviceID, info.revision >= 0,
              info.invoicingGeneration > 0, (info.minimumProtocolVersion ?? 1) > 0 else {
            throw SyncTransportError.invalidResponse
        }
        return info
    }

    func push(_ batch: SyncBatch) async throws -> SyncPushReceipt {
        try await push(batch, protocolVersion: .legacy)
    }

    func push(_ batch: SyncBatch, protocolVersion: SyncProtocolVersion) async throws -> SyncPushReceipt {
        let receipt: SyncPushReceipt
        do {
            receipt = try await client
                .rpc(protocolVersion == .legacy ? "ff_sync_push" : (protocolVersion == .holds ? "ff_sync_push_v2" : "ff_sync_push_v3"),
                     params: PushParameters(p_batch: batch))
                .execute().value
        } catch let error as PostgrestError where error.code == "40001" {
            // This is a rolled-back write, not a timeout with an unknown result.
            throw SyncTransportError.revisionConflict
        } catch let error as PostgrestError where error.code == "42501" && error.message == "Designated invoicing device required" {
            throw SyncTransportError.invoicingDeviceRejected
        } catch let error as PostgrestError where error.code == "P0001" {
            switch error.message {
            case "FF_ALREADY_BILLED": throw SyncTransportError.confirmedRejection(.alreadyBilled)
            case "FF_INVOICE_NUMBER_COLLISION": throw SyncTransportError.confirmedRejection(.invoiceNumberCollision)
            case "FF_PROTOCOL_UPGRADE_REQUIRED": throw SyncTransportError.confirmedRejection(.protocolUpgradeRequired)
            default: throw error
            }
        }
        guard receipt.operationID == batch.operationID, receipt.revision > 0,
              batch.mutations.allSatisfy({ receipt.revision > $0.expectedRevision }) else {
            throw SyncTransportError.invalidResponse
        }
        return receipt
    }

    func takeOverInvoicing(workspaceID: UUID, deviceID: UUID, generation: Int64) async throws -> SyncInvoiceTakeoverReceipt {
        guard generation > 0, generation < Int64.max else { throw SyncTransportError.invalidResponse }
        let receipt: SyncInvoiceTakeoverReceipt
        do {
            receipt = try await client.rpc("ff_invoicing_takeover", params: TakeoverParameters(
                p_workspace: workspaceID, p_device: deviceID, p_generation: generation
            )).execute().value
        } catch let error as PostgrestError where error.code == "40001" {
            throw SyncTransportError.revisionConflict
        }
        guard receipt.invoicingDeviceID == deviceID, receipt.invoicingGeneration == generation + 1,
              receipt.revision > 0 else { throw SyncTransportError.invalidResponse }
        return receipt
    }

    func pull(workspaceID: UUID, cursor: Int64) async throws -> SyncPullPage {
        try await pull(workspaceID: workspaceID, cursor: cursor, protocolVersion: .legacy)
    }

    func pull(workspaceID: UUID, cursor: Int64, protocolVersion: SyncProtocolVersion) async throws -> SyncPullPage {
        guard cursor >= 0 else { throw SyncTransportError.invalidResponse }
        let page: SyncPullPage = try await client
            .rpc(protocolVersion == .legacy ? "ff_sync_pull" : (protocolVersion == .holds ? "ff_sync_pull_v2" : "ff_sync_pull_v3"), params: PullParameters(
                p_workspace: workspaceID, p_cursor: cursor, p_limit: 50
            )).execute().value
        guard page.workspaceID == workspaceID, page.invoicingGeneration > 0,
              page.transactions.count <= 50 else {
            throw SyncTransportError.invalidResponse
        }
        var expected = cursor
        for transaction in page.transactions {
            guard expected < Int64.max, transaction.workspaceID == workspaceID,
                  transaction.revision == expected + 1,
                  transaction.mutations.count <= 10_000 else {
                throw SyncTransportError.invalidResponse
            }
            var seen = Set<UUID>()
            for mutation in transaction.mutations {
                guard seen.insert(mutation.id).inserted,
                      mutation.expectedRevision >= 0,
                      mutation.expectedRevision < transaction.revision,
                      mutation.record == nil ||
                        (mutation.record?.id == mutation.id && mutation.record?.kind == mutation.kind)
                else { throw SyncTransportError.invalidResponse }
            }
            expected = transaction.revision
        }
        guard page.cursor == expected, !page.hasMore || page.cursor > cursor else {
            throw SyncTransportError.invalidResponse
        }
        return page
    }

    private struct BootstrapParameters: Encodable { let p_device: UUID }
    private struct PushParameters: Encodable { let p_batch: SyncBatch }
    private struct TakeoverParameters: Encodable {
        let p_workspace: UUID
        let p_device: UUID
        let p_generation: Int64
    }
    private struct PullParameters: Encodable {
        let p_workspace: UUID
        let p_cursor: Int64
        let p_limit: Int
    }
}
