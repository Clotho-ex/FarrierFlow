import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppointmentDetailModel {
    @ObservationIgnored
    private var displayContext: ModelContext?
    private(set) var appointment: Appointment?
    private(set) var appointmentID: PersistentIdentifier?
    var visitPresentation: VisitPresentation?
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        displayContext = context
        appointmentID = id
        appointment = context.model(for: id) as? Appointment
    }

    func delete(
        in context: ModelContext,
        coordinator: PersistenceMutationCoordinator,
        deleting: (Appointment, ModelContext) throws -> Void = { appointment, context in
            try RecordDeletionRules.delete(appointment, in: context)
        }
    ) -> Bool {
        guard appointment != nil, let appointmentID else { return false }
        return coordinator.withMutation {
            let actionAppointment: Appointment?
            do {
                actionAppointment = try context.existingModel(
                    Appointment.self,
                    for: appointmentID
                )
            } catch {
                displayContext = context
                alert = FeatureAlert(
                    title: "Couldn’t Delete Appointment",
                    message: "The appointment wasn’t deleted. Try again."
                )
                return false
            }
            guard let appointment = actionAppointment else {
                self.appointment = nil
                alert = FeatureAlert(
                    title: "Appointment Unavailable",
                    message: "The appointment couldn’t be found. Try again."
                )
                return false
            }
            do {
                try deleting(appointment, context)
                self.appointment = nil
                self.appointmentID = nil
                displayContext = nil
                return true
            } catch let block as RecordDeletionBlock {
                alert = block.alert
                return false
            } catch {
                displayContext = context
                alert = FeatureAlert(
                    title: "Couldn’t Delete Appointment",
                    message: "The appointment wasn’t deleted. Try again."
                )
                return false
            }
        }
    }

    func startVisit(
        now: Date = .now,
        in container: ModelContainer,
        coordinator: PersistenceMutationCoordinator
    ) {
        guard let appointment else { return }

        do {
            let visitID = try VisitStartUseCase.start(
                appointmentID: appointment.persistentModelID,
                now: now,
                in: container,
                coordinator: coordinator
            )
            visitPresentation = .editor(visitID)
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Start Visit",
                message: "The visit wasn’t started. Try again."
            )
        }
    }

    func present(_ visit: Visit) {
        let presentation: VisitPresentation = visit.completedAt == nil
            ? .editor(visit.persistentModelID)
            : .detail(visit.persistentModelID)
        visitPresentation = presentation
    }

    var editorPresentation: VisitPresentation? {
        get {
            guard let visitPresentation, case .editor = visitPresentation else { return nil }
            return visitPresentation
        }
        set {
            if newValue == nil, let visitPresentation, case .editor = visitPresentation {
                self.visitPresentation = nil
            }
        }
    }

    var detailPresentation: VisitPresentation? {
        get {
            guard let visitPresentation, case .detail = visitPresentation else { return nil }
            return visitPresentation
        }
        set {
            if newValue == nil, let visitPresentation, case .detail = visitPresentation {
                self.visitPresentation = nil
            }
        }
    }
}
