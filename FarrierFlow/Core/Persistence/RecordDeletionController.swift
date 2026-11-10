import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class RecordDeletionController {
    private(set) var impact: RecordDeletionImpact?
    private(set) var isDeleting = false
    var alert: FeatureAlert?

    func prepare(_ target: RecordDeletionTarget, in container: ModelContainer) {
        alert = nil
        do {
            impact = try RecordDeletionPlan(target: target, in: ModelContext(container)).impact
        } catch {
            impact = nil
            show(error)
        }
    }

    func delete(_ confirmed: RecordDeletionImpact, using library: PhotographLibrary) async -> Bool {
        guard !isDeleting else { return false }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await library.deleteRecords(confirming: confirmed)
            impact = nil
            alert = nil
            return true
        } catch {
            show(error)
            return false
        }
    }

    private func show(_ error: Error) {
        if let block = error as? RecordDeletionBlock {
            alert = block.alert
            return
        }
        let message: LocalizedStringResource
        switch error {
        case RecordDeletionError.dependenciesChanged:
            message = "Some details have changed. Review them and try again. Nothing was deleted."
        case RecordDeletionError.unavailable:
            message = "This record is no longer available."
        case PhotographLibraryError.protectedDataUnavailable:
            message = "Unlock your iPhone, then try again. Your records and photos are unchanged."
        case PhotographLibraryError.quarantineRestoreFailed:
            message = "Your records are safe. Reopen FarrierFlow to restore the photos before trying again."
        default:
            message = "Your records and photos are unchanged. Please try again."
        }
        alert = FeatureAlert(title: "Couldn’t Delete", message: message)
    }
}
