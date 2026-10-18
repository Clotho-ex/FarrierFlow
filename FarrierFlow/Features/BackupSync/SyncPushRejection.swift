import Foundation

nonisolated enum SyncProtocolVersion: Int, Codable, Sendable {
    case legacy = 1, holds = 2
}

nonisolated enum SyncPushRejectionReason: String, Codable, Sendable {
    case invoicingAuthority, invoiceNumberCollision, alreadyBilled, protocolUpgradeRequired
}

nonisolated struct SyncConfirmedRejection: Codable, Equatable, Sendable {
    let batch: SyncBatch
    let protocolVersion: SyncProtocolVersion
    let reason: SyncPushRejectionReason
}
