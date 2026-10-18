import Foundation

nonisolated struct SyncPhotoReport: Equatable, Sendable {
    let protectedIDs: [UUID]
    let missingIDs: [UUID]
    let needsReviewIDs: [UUID]
}

@MainActor
final class SyncPhotographTransfer {
    private let store: SyncJournalStore
    private let library: PhotographLibrary
    private let transport: any SyncPhotoTransport

    init(store: SyncJournalStore, library: PhotographLibrary, transport: any SyncPhotoTransport) {
        self.store = store
        self.library = library
        self.transport = transport
    }

    func sync(accountID: UUID, checking: @escaping @MainActor @Sendable () throws -> Void) async throws -> SyncPhotoReport {
        try check(checking)
        guard let journal = try store.journal() else { throw SyncJournalStoreError.unbound }
        try journal.verifyBinding(accountID: accountID, workspaceID: journal.workspaceID)
        for id in journal.pendingPhotoDeletionIDs {
            try check(checking)
            try await transport.delete(workspaceID: journal.workspaceID, photoID: id)
            try check(checking)
            try store.update {
                try $0.verifyBinding(accountID: accountID, workspaceID: journal.workspaceID)
                try $0.confirmPhotoDeletion(id: id)
            }
        }
        try await library.prepareAndReconcile()
        try check(checking)
        let manifest = try await transport.manifest(workspaceID: journal.workspaceID)
        try check(checking)
        var byID: [UUID: SyncPhotoManifestEntry] = [:]
        for entry in manifest {
            guard entry.isValid, byID.updateValue(entry, forKey: entry.id) == nil else {
                throw SyncTransportError.invalidResponse
            }
        }
        var protected: [UUID] = []
        var missing: [UUID] = []
        var review: [UUID] = []
        var checkpoint: [SyncPhotoManifestEntry] = []
        do {
            for record in journal.baseline where record.kind == .photograph {
                try check(checking)
                do {
                    if let entry = try await syncPhoto(
                        record, manifest: byID[record.id], workspaceID: journal.workspaceID, checking: checking
                    ) {
                        checkpoint.append(entry)
                        protected.append(record.id)
                        if checkpoint.count == 200 {
                            try flush(checkpoint, journal: journal, checking: checking)
                            checkpoint.removeAll(keepingCapacity: true)
                        }
                    } else {
                        missing.append(record.id)
                    }
                } catch PhotographLibraryError.photographUnavailable {
                    // A locally deleted photo must not be resurrected by a
                    // download that began before its metadata was deleted.
                    continue
                } catch is SyncPhotoPayloadError {
                    review.append(record.id)
                }
            }
        } catch {
            try flush(checkpoint, journal: journal, checking: checking)
            throw error
        }
        try flush(checkpoint, journal: journal, checking: checking)
        if missing.isEmpty, review.isEmpty {
            try check(checking)
            try store.update { $0.lastPhotographCheck = .now }
        }
        return SyncPhotoReport(protectedIDs: protected, missingIDs: missing, needsReviewIDs: review)
    }

    private func syncPhoto(
        _ record: SyncRecord, manifest: SyncPhotoManifestEntry?, workspaceID: UUID,
        checking: @escaping @MainActor @Sendable () throws -> Void
    ) async throws -> SyncPhotoManifestEntry? {
        let local = try await library.canonicalPayloadForSync(record: record)
        try check(checking)
        if let manifest {
            guard record.fields["byteCount"] == .integer(manifest.byteCount) else {
                throw SyncPhotoPayloadError.invalidMetadata
            }
            if let local {
                guard local.digest == manifest.digest else { throw SyncPhotoPayloadError.digestMismatch }
            } else {
                let bytes = try await transport.download(workspaceID: workspaceID, photoID: record.id)
                try check(checking)
                let payload = try SyncPhotoPayload.validate(data: bytes, record: record, expectedDigest: manifest.digest)
                _ = try await library.restoreForSync(payload: payload, record: record, checking: checking)
                try check(checking)
            }
            return manifest
        }
        guard let local else { return nil }
        do {
            try await transport.upload(workspaceID: workspaceID, payload: local)
            try check(checking)
        } catch {
            try check(checking)
            if error is CancellationError { throw error }
            // A prior interrupted upload may have created the immutable
            // object without its manifest. Verify it, never overwrite it.
            let bytes = try await transport.download(workspaceID: workspaceID, photoID: record.id)
            try check(checking)
            _ = try SyncPhotoPayload.validate(data: bytes, record: record, expectedDigest: local.digest)
        }
        let stillLocal = try await library.canonicalPayloadForSync(record: record)
        try check(checking)
        guard stillLocal?.digest == local.digest else { throw SyncPhotoPayloadError.digestMismatch }
        let receipt = try await transport.commit(workspaceID: workspaceID, payload: local)
        try check(checking)
        guard receipt.isValid, receipt.id == local.id, receipt.digest == local.digest,
              receipt.byteCount == Int64(local.data.count) else { throw SyncTransportError.invalidResponse }
        _ = try await library.canonicalPayloadForSync(record: record)
        try check(checking)
        return receipt
    }

    private func flush(
        _ entries: [SyncPhotoManifestEntry], journal: SyncJournal,
        checking: @MainActor @Sendable () throws -> Void
    ) throws {
        try check(checking)
        guard !entries.isEmpty else { return }
        try store.update {
            try $0.verifyBinding(accountID: journal.accountID, workspaceID: journal.workspaceID)
            try $0.markPhotosVerified(entries)
        }
    }

    private func check(_ checking: @MainActor @Sendable () throws -> Void) throws {
        try Task.checkCancellation()
        try checking()
    }
}
