import Foundation

nonisolated enum SyncMergeResult: Equatable {
    case merged(SyncRecord?)
    case conflict
}

nonisolated enum SyncRecordMerge {
    static func conflictingFields(base: SyncRecord?, local: SyncRecord?, remote: SyncRecord?) -> Set<String>? {
        guard let base, let local, let remote else { return nil }
        return Set(base.fields.keys).union(local.fields.keys).union(remote.fields.keys).filter {
            local.fields[$0] != base.fields[$0] && remote.fields[$0] != base.fields[$0] &&
                local.fields[$0] != remote.fields[$0]
        }
    }

    static func merge(
        base: SyncRecord?, local: SyncRecord?, remote: SyncRecord?
    ) -> SyncMergeResult {
        let records = [base, local, remote].compactMap { $0 }
        guard Set(records.map(\.id)).count <= 1,
              Set(records.map(\.kind)).count <= 1 else { return .conflict }
        if local == remote { return .merged(local) }
        if local == base { return .merged(remote) }
        if remote == base { return .merged(local) }
        guard let base, let local, let remote else { return .conflict }
        var fields = base.fields
        for key in Set(base.fields.keys).union(local.fields.keys).union(remote.fields.keys) {
            let oldValue = base.fields[key]
            let localValue = local.fields[key]
            let remoteValue = remote.fields[key]
            if localValue != oldValue, remoteValue != oldValue,
               localValue != remoteValue { return .conflict }
            fields[key] = localValue != oldValue ? localValue : remoteValue
        }
        return .merged(SyncRecord(id: base.id, kind: base.kind, fields: fields))
    }
}

nonisolated struct SyncRemoteTransaction: Codable, Equatable, Sendable {
    let workspaceID: UUID
    let revision: Int64
    let mutations: [SyncMutation]
}

nonisolated struct SyncConflict: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let kind: SyncRecordKind
    let local: SyncRecord?
    let remote: SyncRecord?
    // Nil also decodes older journals conservatively as a whole-record conflict.
    var unresolvedFields: Set<String>? = nil
}
