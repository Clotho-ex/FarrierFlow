import Foundation
import OSLog
import SwiftData

nonisolated enum PhotographReconciliationAction: Equatable, Sendable {
    case restore(source: URL, destination: URL)
    case purge(URL)
}

@MainActor
enum PhotographReconciler {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "PhotographReconciliation"
    )

    static func reconcile(
        in container: ModelContainer,
        fileStore: PhotographFileStore,
        protectedDataIsAvailable: Bool
    ) throws {
        guard protectedDataIsAvailable else {
            throw PhotographLibraryError.protectedDataUnavailable
        }

        let context = ModelContext(container)
        let photographs = try context.fetch(FetchDescriptor<Photograph>())
        let metadataIDs = Set(photographs.map(\.id))
        let inspection = try fileStore.inspectAllEntries()
        let actions = try plan(
            metadataIDs: metadataIDs,
            inspection: inspection,
            fileStore: fileStore
        )

        for entry in inspection.unknownEntries {
            logger.warning("Retaining unmanaged photograph entry: \(entry.lastPathComponent, privacy: .public)")
        }
        for action in actions {
            switch action {
            case .restore(let source, let destination):
                try fileStore.moveWithoutOverwriting(from: source, to: destination)
                try fileStore.applyCompleteProtection(to: destination)
            case .purge(let url):
                try fileStore.removeManagedFile(at: url)
            }
        }
    }

    static func plan(
        metadataIDs: Set<UUID>,
        inspection: PhotographFileInspection,
        fileStore: PhotographFileStore
    ) throws -> [PhotographReconciliationAction] {
        for id in metadataIDs
        where inspection.canonicalFiles[id] == nil
            && (inspection.quarantineFiles[id]?.count ?? 0) > 1 {
            throw PhotographLibraryError.ambiguousQuarantine
        }

        var actions: [PhotographReconciliationAction] = []
        for temporary in inspection.temporaryFiles {
            actions.append(.purge(temporary.url))
        }

        for (id, canonicalURL) in inspection.canonicalFiles {
            if metadataIDs.contains(id) {
                for quarantine in inspection.quarantineFiles[id] ?? [] {
                    actions.append(.purge(quarantine.url))
                }
            } else {
                actions.append(.purge(canonicalURL))
            }
        }

        for (id, quarantines) in inspection.quarantineFiles {
            if !metadataIDs.contains(id) {
                actions.append(contentsOf: quarantines.map { .purge($0.url) })
            } else if inspection.canonicalFiles[id] == nil, let quarantine = quarantines.first {
                actions.append(
                    .restore(
                        source: quarantine.url,
                        destination: fileStore.canonicalURL(for: id)
                    )
                )
            }
        }
        return actions
    }
}
