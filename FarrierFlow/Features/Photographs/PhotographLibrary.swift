import Foundation
import Observation
import SwiftData
import UIKit

@MainActor
@Observable
final class PhotographLibrary {
    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored let fileStore: PhotographFileStore
    @ObservationIgnored private let normalizer: PhotographNormalizer
    @ObservationIgnored private let coordinator: PhotographStorageCoordinator
    @ObservationIgnored private let protectedDataAvailable: @MainActor () -> Bool
    @ObservationIgnored private let saving: @MainActor (ModelContext) throws -> Void
    @ObservationIgnored private let discarding: @MainActor (Visit, ModelContext) throws -> Void
    @ObservationIgnored private let hooks: PhotographOperationHooks
    @ObservationIgnored private let syncPhotoReader = SyncPhotoFileReader()

    init(
        container: ModelContainer,
        fileStore: PhotographFileStore,
        normalizer: PhotographNormalizer = PhotographNormalizer(),
        coordinator: PhotographStorageCoordinator = PhotographStorageCoordinator(),
        protectedDataAvailable: @escaping @MainActor () -> Bool = {
            UIApplication.shared.isProtectedDataAvailable
        },
        saving: @escaping @MainActor (ModelContext) throws -> Void = {
            try DomainGraphValidator.save($0)
        },
        discarding: @escaping @MainActor (Visit, ModelContext) throws -> Void = {
            try RecordDeletionRules.delete($0, in: $1)
        },
        hooks: PhotographOperationHooks = .production
    ) {
        self.container = container
        self.fileStore = fileStore
        self.normalizer = normalizer
        self.coordinator = coordinator
        self.protectedDataAvailable = protectedDataAvailable
        self.saving = saving
        self.discarding = discarding
        self.hooks = hooks
    }

    func prepareAndReconcile() async throws {
        try await coordinator.withExclusiveOperation { @MainActor [self] in
            try fileStore.prepareDirectories()
            try await hooks.beforeReconciliationInspection()
            let retained = try PhotographReconciler.reconcile(
                in: container,
                fileStore: fileStore,
                protectedDataIsAvailable: protectedDataAvailable()
            )
            await syncPhotoReader.retain(retained)
        }
    }

    func items(for visitHorseID: PersistentIdentifier) throws -> [PhotographItem] {
        guard protectedDataAvailable() else {
            throw PhotographLibraryError.protectedDataUnavailable
        }
        let context = ModelContext(container)
        guard let visitHorse = try context.existingModel(
            VisitHorse.self,
            for: visitHorseID
        ) else {
            throw PhotographLibraryError.visitHorseUnavailable
        }
        return try visitHorse.photographs.map { photograph in
            PhotographItem(
                id: photograph.id,
                createdAt: photograph.createdAt,
                pixelWidth: photograph.pixelWidth,
                pixelHeight: photograph.pixelHeight,
                byteCount: photograph.byteCount,
                availability: try fileStore.canonicalFileIsAvailable(for: photograph.id)
                    ? .available
                    : .unavailable
            )
        }.sorted {
            if $0.createdAt != $1.createdAt {
                return $0.createdAt < $1.createdAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func add(
        sourceData: Data,
        to visitHorseID: PersistentIdentifier,
        id: UUID = UUID(),
        createdAt: Date = .now
    ) async throws -> UUID {
        try await coordinator.withExclusiveOperation { @MainActor [self] in
            try await addExclusive(
                sourceData: sourceData,
                to: visitHorseID,
                id: id,
                createdAt: createdAt
            )
        }
    }

    func delete(id: UUID) async throws {
        try await coordinator.withExclusiveOperation { @MainActor [self] in
            try await deleteExclusive(id: id)
        }
    }

    func discardInProgressVisit(id visitID: PersistentIdentifier) async throws {
        try await coordinator.withExclusiveOperation { @MainActor [self] in
            try await discardExclusive(visitID: visitID)
        }
    }

    func deleteRecords(confirming impact: RecordDeletionImpact) async throws {
        try await coordinator.withExclusiveOperation { @MainActor [self] in
            let previewContext = ModelContext(container)
            guard try RecordDeletionPlan(target: impact.target, in: previewContext).impact == impact else {
                throw RecordDeletionError.dependenciesChanged
            }
            if !impact.photoIDs.isEmpty {
                try fileStore.prepareDirectories()
                guard protectedDataAvailable() else { throw PhotographLibraryError.protectedDataUnavailable }
            }
            var quarantines: [(source: URL, destination: URL)] = []
            do {
                for id in impact.photoIDs {
                    guard try fileStore.canonicalFileIsAvailable(for: id) else { continue }
                    let canonical = fileStore.canonicalURL(for: id)
                    let quarantine = fileStore.quarantineURL(photoID: id, operationID: UUID())
                    try fileStore.moveWithoutOverwriting(from: canonical, to: quarantine)
                    quarantines.append((source: quarantine, destination: canonical))
                    try fileStore.applyCompleteProtection(to: quarantine)
                }
                try await hooks.afterDiscardQuarantineMoves()
                try Task.checkCancellation()
                // Refresh after suspension so new relationships cannot silently
                // expand what the user confirmed.
                try RecordDeletionPlan.execute(
                    impact.target, confirming: impact, in: ModelContext(container), saving: saving
                )
            } catch {
                do { try restoreQuarantines(quarantines) }
                catch { throw PhotographLibraryError.quarantineRestoreFailed }
                throw error
            }
            // Metadata is committed. Reconciliation can clean up any leftover quarantine.
            for quarantine in quarantines {
                try? fileStore.removeManagedFile(at: quarantine.source)
            }
        }
    }

    func canonicalURL(for id: UUID) -> URL {
        fileStore.canonicalURL(for: id)
    }

    func canonicalPayloadForSync(record: SyncRecord) async throws -> SyncPhotoPayload? {
        try await coordinator.withExclusiveOperation { @MainActor [self] in
            try Task.checkCancellation()
            guard protectedDataAvailable() else { throw PhotographLibraryError.protectedDataUnavailable }
            try requireCurrentSyncPhoto(record)
            try fileStore.prepareDirectories()
            let url = fileStore.canonicalURL(for: record.id)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            guard try fileStore.canonicalFileIsAvailable(for: record.id) else {
                throw PhotographFileStoreError.expectedRegularFile
            }
            let payload = try await syncPhotoReader.payload(url: url, record: record)
            try Task.checkCancellation()
            guard protectedDataAvailable() else { throw PhotographLibraryError.protectedDataUnavailable }
            try requireCurrentSyncPhoto(record)
            return payload
        }
    }

    func verifyPhotoForSync(record: SyncRecord, receipt: SyncPhotoManifestEntry) async throws -> Bool {
        try await coordinator.withExclusiveOperation { @MainActor [self] in
            try Task.checkCancellation()
            guard protectedDataAvailable() else { throw PhotographLibraryError.protectedDataUnavailable }
            try requireCurrentSyncPhoto(record)
            let url = fileStore.canonicalURL(for: record.id)
            guard FileManager.default.fileExists(atPath: url.path) else { return false }
            try await syncPhotoReader.verify(url: url, record: record, receipt: receipt)
            try Task.checkCancellation()
            guard protectedDataAvailable() else { throw PhotographLibraryError.protectedDataUnavailable }
            try requireCurrentSyncPhoto(record)
            return true
        }
    }

    func restoreForSync(
        payload: SyncPhotoPayload, record: SyncRecord,
        checking: @escaping @MainActor @Sendable () throws -> Void
    ) async throws -> Bool {
        try await coordinator.withExclusiveOperation { @MainActor [self] in
            try Task.checkCancellation()
            try checking()
            guard protectedDataAvailable() else { throw PhotographLibraryError.protectedDataUnavailable }
            try requireCurrentSyncPhoto(record)
            guard payload.id == record.id else { throw SyncPhotoPayloadError.invalidMetadata }
            try await Task.detached(priority: .utility) {
                _ = try SyncPhotoPayload.validate(data: payload.data, record: record, expectedDigest: payload.digest)
            }.value
            try Task.checkCancellation()
            guard protectedDataAvailable() else { throw PhotographLibraryError.protectedDataUnavailable }
            try checking()
            try requireCurrentSyncPhoto(record)
            try fileStore.prepareDirectories()
            let canonical = fileStore.canonicalURL(for: record.id)
            if FileManager.default.fileExists(atPath: canonical.path) {
                guard try fileStore.canonicalFileIsAvailable(for: record.id) else {
                    throw PhotographFileStoreError.expectedRegularFile
                }
                try await syncPhotoReader.verify(url: canonical, record: record,
                    receipt: .init(id: payload.id, digest: payload.digest, byteCount: Int64(payload.data.count)))
                try Task.checkCancellation()
                guard protectedDataAvailable() else { throw PhotographLibraryError.protectedDataUnavailable }
                try checking()
                try requireCurrentSyncPhoto(record)
                try fileStore.applyCompleteProtection(to: canonical)
                return false
            }
            if let capacity = try fileStore.availableCapacityForImportantUsage(),
               capacity < Int64(payload.data.count) * 2 {
                throw PhotographLibraryError.insufficientStorage
            }
            let temporary = fileStore.temporaryURL(photoID: record.id, operationID: UUID())
            do {
                try payload.data.write(to: temporary, options: [.atomic, .completeFileProtection])
                try fileStore.applyCompleteProtection(to: temporary)
                try checking()
                try Task.checkCancellation()
                try fileStore.moveWithoutOverwriting(from: temporary, to: canonical)
                try fileStore.applyCompleteProtection(to: canonical)
                return true
            } catch {
                do { try removeIfManagedFileExists(at: temporary) }
                catch { throw PhotographLibraryError.rollbackCleanupFailed }
                throw mappedAddError(error)
            }
        }
    }

    private func requireCurrentSyncPhoto(_ record: SyncRecord) throws {
        let id = record.id
        let context = ModelContext(container)
        let matches = try context.fetch(FetchDescriptor<Photograph>(predicate: #Predicate { $0.id == id }))
        guard let photo = matches.first else { throw PhotographLibraryError.photographUnavailable }
        guard matches.count == 1, photo.visitHorse?.visit != nil, photo.visitHorse?.horse != nil,
              try SyncGraphCodec.photographRecord(photo) == record else {
            throw PhotographLibraryError.invalidPhotographGraph
        }
    }

    private func addExclusive(
        sourceData: Data,
        to visitHorseID: PersistentIdentifier,
        id: UUID,
        createdAt: Date
    ) async throws -> UUID {
        try fileStore.prepareDirectories()
        guard protectedDataAvailable() else {
            throw PhotographLibraryError.protectedDataUnavailable
        }

        let context = ModelContext(container)
        guard let visitHorse = try context.existingModel(
            VisitHorse.self,
            for: visitHorseID
        ), visitHorse.visit != nil, visitHorse.horse != nil else {
            throw PhotographLibraryError.visitHorseUnavailable
        }
        let existingIdentityCount = try context.fetchCount(
            FetchDescriptor<Photograph>(
                predicate: #Predicate { $0.id == id }
            )
        )
        guard existingIdentityCount == 0 else {
            throw PhotographFileStoreError.destinationExists
        }

        let availableCount = try visitHorse.photographs.reduce(into: 0) { count, photograph in
            if try fileStore.canonicalFileIsAvailable(for: photograph.id) {
                count += 1
            }
        }
        guard availableCount < PhotographConstants.maximumPhotographsPerVisitHorse else {
            throw PhotographLibraryError.photographLimitReached
        }

        try ensureCapacityBeforeNormalization(for: sourceData)

        let operationID = UUID()
        let temporaryURL = fileStore.temporaryURL(photoID: id, operationID: operationID)
        let canonicalURL = fileStore.canonicalURL(for: id)
        guard !FileManager.default.fileExists(atPath: canonicalURL.path) else {
            throw PhotographFileStoreError.destinationExists
        }

        let normalized: NormalizedPhotograph
        var movedToCanonical = false
        do {
            normalized = try await normalizer.normalize(
                data: sourceData,
                destinationURL: temporaryURL
            )
            try fileStore.applyCompleteProtection(to: temporaryURL)
            try fileStore.moveWithoutOverwriting(from: temporaryURL, to: canonicalURL)
            movedToCanonical = true
            try fileStore.applyCompleteProtection(to: canonicalURL)
            try await hooks.afterAddCanonicalMove()
        } catch {
            try? removeIfManagedFileExists(at: temporaryURL)
            if movedToCanonical {
                do {
                    try fileStore.removeManagedFile(at: canonicalURL)
                } catch {
                    throw PhotographLibraryError.rollbackCleanupFailed
                }
            }
            throw mappedAddError(error)
        }

        let photograph = Photograph(
            id: id,
            createdAt: createdAt,
            pixelWidth: normalized.pixelWidth,
            pixelHeight: normalized.pixelHeight,
            byteCount: normalized.byteCount,
            visitHorse: visitHorse
        )
        context.insert(photograph)
        visitHorse.photographs.append(photograph)
        do {
            try saving(context)
            return id
        } catch {
            context.rollback()
            do {
                try fileStore.removeManagedFile(at: canonicalURL)
            } catch {
                throw PhotographLibraryError.rollbackCleanupFailed
            }
            throw PhotographLibraryError.persistenceFailed
        }
    }

    private func deleteExclusive(id: UUID) async throws {
        try fileStore.prepareDirectories()
        guard protectedDataAvailable() else {
            throw PhotographLibraryError.protectedDataUnavailable
        }

        let context = ModelContext(container)
        let photographs = try context.fetch(
            FetchDescriptor<Photograph>(
                predicate: #Predicate { $0.id == id }
            )
        )
        guard photographs.count == 1, let photograph = photographs.first else {
            throw PhotographLibraryError.photographUnavailable
        }
        guard let visitHorse = photograph.visitHorse,
              visitHorse.photographs.contains(where: { $0 === photograph })
        else {
            throw PhotographLibraryError.invalidPhotographGraph
        }

        let canonicalURL = fileStore.canonicalURL(for: id)
        let quarantineURL = fileStore.quarantineURL(photoID: id, operationID: UUID())
        let movedToQuarantine: Bool
        if try fileStore.canonicalFileIsAvailable(for: id) {
            try fileStore.moveWithoutOverwriting(from: canonicalURL, to: quarantineURL)
            try fileStore.applyCompleteProtection(to: quarantineURL)
            movedToQuarantine = true
        } else {
            movedToQuarantine = false
        }
        do {
            try await hooks.afterDeleteQuarantineMove()
        } catch {
            if movedToQuarantine {
                do {
                    try fileStore.moveWithoutOverwriting(
                        from: quarantineURL,
                        to: canonicalURL
                    )
                } catch {
                    throw PhotographLibraryError.quarantineRestoreFailed
                }
            }
            throw error
        }

        visitHorse.photographs.removeAll { $0 === photograph }
        context.delete(photograph)
        do {
            try saving(context)
        } catch {
            context.rollback()
            if movedToQuarantine {
                do {
                    try await hooks.beforeDeleteQuarantineRestore()
                    try fileStore.moveWithoutOverwriting(
                        from: quarantineURL,
                        to: canonicalURL
                    )
                } catch {
                    throw PhotographLibraryError.quarantineRestoreFailed
                }
            }
            throw PhotographLibraryError.persistenceFailed
        }

        if movedToQuarantine {
            try? fileStore.removeManagedFile(at: quarantineURL)
        }
    }

    private func discardExclusive(visitID: PersistentIdentifier) async throws {
        try fileStore.prepareDirectories()
        guard protectedDataAvailable() else {
            throw PhotographLibraryError.protectedDataUnavailable
        }

        let context = ModelContext(container)
        guard let visit = try context.existingModel(Visit.self, for: visitID),
              visit.completedAt == nil else {
            throw VisitSaveError.visitUnavailable
        }

        var quarantines: [(source: URL, destination: URL)] = []
        do {
            for photograph in visit.visitHorses.flatMap(\.photographs) {
                let canonical = fileStore.canonicalURL(for: photograph.id)
                guard try fileStore.canonicalFileIsAvailable(for: photograph.id) else {
                    continue
                }
                let quarantine = fileStore.quarantineURL(
                    photoID: photograph.id,
                    operationID: UUID()
                )
                try fileStore.moveWithoutOverwriting(from: canonical, to: quarantine)
                try fileStore.applyCompleteProtection(to: quarantine)
                quarantines.append((source: quarantine, destination: canonical))
            }
            try await hooks.afterDiscardQuarantineMoves()
        } catch {
            try restoreQuarantines(quarantines)
            throw error
        }

        do {
            try discarding(visit, context)
        } catch {
            do {
                try restoreQuarantines(quarantines)
            } catch {
                throw PhotographLibraryError.quarantineRestoreFailed
            }
            throw error
        }

        for quarantine in quarantines {
            try? fileStore.removeManagedFile(at: quarantine.source)
        }
    }

    private func restoreQuarantines(
        _ quarantines: [(source: URL, destination: URL)]
    ) throws {
        for quarantine in quarantines.reversed() {
            try fileStore.moveWithoutOverwriting(
                from: quarantine.source,
                to: quarantine.destination
            )
            try fileStore.applyCompleteProtection(to: quarantine.destination)
        }
    }

    private func removeIfManagedFileExists(at url: URL) throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try fileStore.removeManagedFile(at: url)
        }
    }

    private func ensureCapacityBeforeNormalization(for sourceData: Data) throws {
        let requiredCapacity = min(
            Int64(max(sourceData.count, 1)),
            PhotographConstants.capacityPreflightMaximumBytes
        )
        if let availableCapacity = try? fileStore.availableCapacityForImportantUsage(),
           availableCapacity < requiredCapacity {
            throw PhotographLibraryError.insufficientStorage
        }
    }

    private func mappedAddError(_ error: any Error) -> any Error {
        guard Self.isOutOfSpace(error) else {
            return error
        }
        return PhotographLibraryError.insufficientStorage
    }

    private static func isOutOfSpace(_ error: any Error) -> Bool {
        let error = error as NSError
        if error.domain == NSCocoaErrorDomain,
           error.code == CocoaError.fileWriteOutOfSpace.rawValue {
            return true
        }
        if error.domain == NSPOSIXErrorDomain,
           error.code == POSIXErrorCode.ENOSPC.rawValue {
            return true
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? any Error {
            return isOutOfSpace(underlying)
        }
        return false
    }

}
