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
        let message: LocalizedStringResource
        switch error {
        case RecordDeletionError.dependenciesChanged:
            message = "The linked records changed. Open Delete again to review the updated warning. Nothing was deleted."
        case RecordDeletionError.unavailable:
            message = "This record is no longer available."
        case PhotographLibraryError.protectedDataUnavailable:
            message = "Unlock your iPhone to access its protected photos, then try deleting again. Nothing was deleted."
        case PhotographLibraryError.quarantineRestoreFailed:
            message = "Your records were kept, but some photos could not be restored yet. Reopen FarrierFlow to recover them before trying again."
        default:
            message = "Nothing was deleted. Your records and photos are unchanged. Try again."
        }
        alert = FeatureAlert(title: "Couldn’t Delete Record", message: message)
    }
}
