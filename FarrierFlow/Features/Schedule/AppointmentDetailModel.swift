import Foundation
import Observation
import SwiftData

struct AppointmentDetail: Equatable {
    struct Horse: Equatable, Identifiable {
        let id: PersistentIdentifier
        let name: String?
        let clientName: String?
        let clientPhone: String?
        let safetyNotes: String?
        let plannedServiceName: String?
    }

    struct Visit: Equatable {
        let id: PersistentIdentifier
        let completedAt: Date?
    }

    let id: PersistentIdentifier
    let startDate: Date
    let barnName: String?
    let barnAddress: String?
    let barnContactNotes: String?
    let expectedDurationMinutes: Int?
    let notes: String?
    let horses: [Horse]
    let visit: Visit?

    init(appointment: Appointment) {
        id = appointment.persistentModelID
        startDate = appointment.startDate
        barnName = appointment.barn?.name
        barnAddress = appointment.barn?.address
        barnContactNotes = appointment.barn?.contactNotes
        expectedDurationMinutes = appointment.expectedDurationMinutes
        notes = appointment.notes
        horses = appointment.appointmentHorses.map { membership in
            let horse = membership.horse
            return Horse(
                id: membership.persistentModelID,
                name: horse?.name,
                clientName: horse?.client?.name,
                clientPhone: horse?.client?.phone,
                safetyNotes: horse?.safetyNotes,
                plannedServiceName: membership.plannedService?.name
            )
        }
        visit = appointment.visit.map {
            Visit(id: $0.persistentModelID, completedAt: $0.completedAt)
        }
    }
}

@MainActor
@Observable
final class AppointmentDetailModel {
    private(set) var detail: AppointmentDetail?
    private(set) var appointmentID: PersistentIdentifier?
    var visitPresentation: VisitPresentation?
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        appointmentID = id
        guard
            let appointment = try? context.existingModel(Appointment.self, for: id)
        else {
            detail = nil
            return
        }
        detail = AppointmentDetail(appointment: appointment)
    }

    func delete(
        in context: ModelContext,
        deleting: (Appointment, ModelContext) throws -> Void = { appointment, context in
            try RecordDeletionRules.delete(appointment, in: context)
        }
    ) -> Bool {
        guard detail != nil, let appointmentID else { return false }
        let actionAppointment: Appointment?
        do {
            actionAppointment = try context.existingModel(
                Appointment.self,
                for: appointmentID
            )
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Delete Appointment",
                message: "The appointment wasn’t deleted. Try again."
            )
            return false
        }
        guard let appointment = actionAppointment else {
            detail = nil
            alert = FeatureAlert(
                title: "Appointment Unavailable",
                message: "The appointment couldn’t be found. Try again."
            )
            return false
        }
        do {
            try deleting(appointment, context)
            detail = nil
            self.appointmentID = nil
            return true
        } catch let block as RecordDeletionBlock {
            alert = block.alert
            return false
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Delete Appointment",
                message: "The appointment wasn’t deleted. Try again."
            )
            return false
        }
    }

    func startVisit(
        now: Date = .now,
        in container: ModelContainer,
        analyticsClient: any AnalyticsClient = NoOpAnalyticsClient()
    ) {
        guard let appointmentID else { return }

        do {
            let visitID = try VisitStartUseCase.start(
                appointmentID: appointmentID,
                now: now,
                in: container,
                analyticsClient: analyticsClient
            )
            visitPresentation = .editor(visitID)
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Start Visit",
                message: "The visit wasn’t started. Try again."
            )
        }
    }

    func present(visitID: PersistentIdentifier, completedAt: Date?) {
        let presentation: VisitPresentation = completedAt == nil
            ? .editor(visitID)
            : .detail(visitID)
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
