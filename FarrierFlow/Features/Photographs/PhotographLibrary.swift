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
            try PhotographReconciler.reconcile(
                in: container,
                fileStore: fileStore,
                protectedDataIsAvailable: protectedDataAvailable()
            )
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

    func canonicalURL(for id: UUID) -> URL {
        fileStore.canonicalURL(for: id)
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
            let availableCapacity = try? fileStore.availableCapacityForImportantUsage()
            if let availableCapacity, availableCapacity < normalized.byteCount {
                throw PhotographLibraryError.insufficientStorage
            }
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
            throw error
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

}
