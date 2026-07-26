import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppointmentDetailModel {
    private(set) var appointment: Appointment?
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        appointment = context.model(for: id) as? Appointment
    }

    func delete(in context: ModelContext) -> Bool {
        guard let appointment else { return false }
        self.appointment = nil
        do {
            try RecordDeletionRules.delete(appointment, in: context)
            return true
        } catch {
            self.appointment = appointment
            alert = FeatureAlert(
                title: "Couldn’t Delete Appointment",
                message: "The appointment wasn’t deleted. Try again."
            )
            return false
        }
    }
}
