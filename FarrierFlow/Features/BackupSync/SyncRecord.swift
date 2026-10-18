import Foundation

nonisolated enum SyncRecordKind: String, Codable, CaseIterable, Sendable {
    case businessProfile, client, barn, service, horse, appointment
    case appointmentHorse, visit, visitHorse, photograph, workItem
    case invoice, invoiceVisit, invoiceLineItem, payment
}

/// JSON primitives intentionally exclude floating-point money and arbitrary objects.
nonisolated enum SyncValue: Equatable, Sendable, Codable {
    case string(String)
    case integer(Int64)
    case boolean(Bool)
    case null

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

nonisolated struct SyncRecord: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let kind: SyncRecordKind
    let fields: [String: SyncValue]
}

nonisolated struct SyncMutation: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let kind: SyncRecordKind
    let expectedRevision: Int64
    let record: SyncRecord?
}

nonisolated struct SyncBatch: Codable, Equatable, Sendable {
    let operationID: UUID
    let workspaceID: UUID
    let deviceID: UUID
    let invoicingGeneration: Int64
    let mutations: [SyncMutation]
}
