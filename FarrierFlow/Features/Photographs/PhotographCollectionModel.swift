import Foundation
import Observation
import OSLog
import SwiftData

@MainActor
@Observable
final class PhotographCollectionModel {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "PhotographCollection"
    )

    @ObservationIgnored private let library: PhotographLibrary
    let visitHorseID: PersistentIdentifier
    let horseName: String

    private(set) var items: [PhotographItem] = []
    private(set) var isLoading = true
    private(set) var isProcessing = false
    var alert: FeatureAlert?

    var availableCount: Int {
        items.count { $0.availability == .available }
    }

    var canAdd: Bool {
        !isProcessing
            && availableCount < PhotographConstants.maximumPhotographsPerVisitHorse
    }

    init(
        visitHorseID: PersistentIdentifier,
        horseName: String,
        library: PhotographLibrary
    ) {
        self.visitHorseID = visitHorseID
        self.horseName = horseName
        self.library = library
    }

    func load() {
        do {
            items = try library.items(for: visitHorseID)
            alert = nil
        } catch {
            Self.logger.error("Failed to load photographs: \(error, privacy: .public)")
            alert = FeatureAlert(
                title: "Photographs Unavailable",
                message: "The photographs couldn’t be loaded. Try again."
            )
        }
        isLoading = false
    }

    func add(sourceData: Data) async {
        guard canAdd else {
            if availableCount >= PhotographConstants.maximumPhotographsPerVisitHorse {
                alert = FeatureAlert(
                    title: "Photograph Limit Reached",
                    message: "This horse already has 16 photographs. Delete one before adding another."
                )
            }
            return
        }
        isProcessing = true
        defer { isProcessing = false }

        do {
            _ = try await library.add(sourceData: sourceData, to: visitHorseID)
            load()
        } catch {
            Self.logger.error("Failed to add photograph: \(error, privacy: .public)")
            alert = addErrorAlert(for: error)
        }
    }

    func delete(id: UUID) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await library.delete(id: id)
            load()
        } catch {
            Self.logger.error("Failed to delete photograph: \(error, privacy: .public)")
            alert = FeatureAlert(
                title: "Couldn’t Delete Photograph",
                message: "The photograph was kept. Try deleting it again."
            )
        }
    }

    private func addErrorAlert(for error: any Error) -> FeatureAlert {
        if error as? PhotographLibraryError == .photographLimitReached {
            return FeatureAlert(
                title: "Photograph Limit Reached",
                message: "This horse already has 16 photographs. Delete one before adding another."
            )
        }
        if error as? PhotographLibraryError == .insufficientStorage {
            return FeatureAlert(
                title: "Not Enough Storage",
                message: "Free some device storage, then try adding the photograph again."
            )
        }
        return FeatureAlert(
            title: "Couldn’t Add Photograph",
            message: "The image couldn’t be processed or saved. Try again."
        )
    }
}
