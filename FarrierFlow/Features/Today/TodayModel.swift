import Foundation
import Observation
import SwiftData

nonisolated enum TodayLoadState: Equatable {
    case loading
    case loaded
    case failed
}

nonisolated struct TodayAppointmentSummary: Hashable, Identifiable {
    let id: PersistentIdentifier
    let startDate: Date
    let serviceLocationName: String
    let serviceLocationAddress: String?
    let horseNames: [String]
}

nonisolated struct TodayVisitSummary: Hashable {
    let id: PersistentIdentifier
    let appointmentID: PersistentIdentifier
    let startedAt: Date
    let serviceLocationName: String
    let serviceLocationAddress: String?
    let horseNames: [String]
    let resolvedHorseCount: Int
    let totalHorseCount: Int
}

nonisolated struct TodayInvoiceCandidate: Hashable {
    let clientID: PersistentIdentifier
    let clientName: String
    let workDate: Date
}

nonisolated struct TodayUnpaidInvoiceSummary: Hashable {
    let id: PersistentIdentifier
    let number: Int64
    let clientName: String
    let invoiceDate: Date
}

nonisolated enum TodayPrimaryAction: Hashable {
    case resumeVisit(TodayVisitSummary)
    case openAppointment(TodayAppointmentSummary)
    case addClient
    case createInvoice(TodayInvoiceCandidate)
    case reviewInvoice(TodayUnpaidInvoiceSummary)
    case scheduleAppointment
}

@MainActor
@Observable
final class TodayModel {
    private(set) var loadState: TodayLoadState = .loading
    private(set) var businessName = ""
    private(set) var primaryAction: TodayPrimaryAction = .scheduleAppointment
    private(set) var remainingAppointments: [TodayAppointmentSummary] = []
    var alert: FeatureAlert?

    func load(in context: ModelContext, now: Date, calendar: Calendar) {
        loadState = .loading
        do {
            businessName = try validBusinessName(in: context)
            let appointments = try appointmentSummaries(
                in: context,
                now: now,
                calendar: calendar
            )

            if let visit = try activeVisitSummaries(in: context).first {
                primaryAction = .resumeVisit(visit)
                remainingAppointments = appointments.filter {
                    $0.id != visit.appointmentID
                }
            } else if let appointment = appointments.first(where: {
                guard let record = context.model(for: $0.id) as? Appointment else {
                    return false
                }
                return record.visit == nil
            }) {
                primaryAction = .openAppointment(appointment)
                remainingAppointments = appointments.filter { $0.id != appointment.id }
            } else if try context.fetchCount(FetchDescriptor<Client>()) == 0 {
                primaryAction = .addClient
                remainingAppointments = appointments
            } else if let invoiceCandidate = try invoiceCandidates(in: context).first {
                primaryAction = .createInvoice(invoiceCandidate)
                remainingAppointments = appointments
            } else if let invoice = try unpaidInvoiceSummaries(in: context).first {
                primaryAction = .reviewInvoice(invoice)
                remainingAppointments = appointments
            } else {
                primaryAction = .scheduleAppointment
                remainingAppointments = appointments
            }

            alert = nil
            loadState = .loaded
        } catch {
            businessName = ""
            primaryAction = .scheduleAppointment
            remainingAppointments = []
            loadState = .failed
            alert = FeatureAlert(
                title: "Couldn’t Load Today",
                message: "FarrierFlow couldn’t load your run sheet. Try again."
            )
        }
    }

    private func validBusinessName(in context: ModelContext) throws -> String {
        var descriptor = FetchDescriptor<BusinessProfile>()
        descriptor.fetchLimit = 2
        let profiles = try context.fetch(descriptor)
        guard profiles.count == 1,
              let profile = profiles.first,
              TextNormalization.required(profile.name) == profile.name
        else {
            throw TodayProjectionError.invalidBusinessProfile
        }
        return profile.name
    }

    private func appointmentSummaries(
        in context: ModelContext,
        now: Date,
        calendar: Calendar
    ) throws -> [TodayAppointmentSummary] {
        let interval = CalendarRules.dayInterval(containing: now, calendar: calendar)
        let start = interval.start
        let end = interval.end
        let appointments = try context.fetch(
            FetchDescriptor<Appointment>(
                predicate: #Predicate {
                    $0.startDate >= start && $0.startDate < end
                },
                sortBy: [SortDescriptor(\.startDate)]
            )
        )
        return try appointments.map { appointment in
            guard
                let barn = appointment.barn,
                let barnName = TextNormalization.required(barn.name)
            else {
                throw TodayProjectionError.invalidAppointment
            }
            let horseNames = appointment.appointmentHorses
                .compactMap { TextNormalization.required($0.horse?.name ?? "") }
                .sorted(using: String.StandardComparator(.localizedStandard))
            guard !horseNames.isEmpty else {
                throw TodayProjectionError.invalidAppointment
            }
            return TodayAppointmentSummary(
                id: appointment.persistentModelID,
                startDate: appointment.startDate,
                serviceLocationName: barnName,
                serviceLocationAddress: TextNormalization.optional(barn.address ?? ""),
                horseNames: horseNames
            )
        }.sorted(by: appointmentOrder)
    }

    private func activeVisitSummaries(
        in context: ModelContext
    ) throws -> [TodayVisitSummary] {
        let visits = try context.fetch(
            FetchDescriptor<Visit>(
                predicate: #Predicate { $0.completedAt == nil },
                sortBy: [SortDescriptor(\.startedAt)]
            )
        )
        return try visits.map { visit in
            guard let appointment = visit.appointment,
                  let location = TextNormalization.required(
                      visit.serviceLocationNameSnapshot
                  ),
                  !visit.visitHorses.isEmpty
            else {
                throw TodayProjectionError.invalidVisit
            }
            let horseNames = visit.visitHorses
                .compactMap { TextNormalization.required($0.horse?.name ?? "") }
                .sorted(using: String.StandardComparator(.localizedStandard))
            guard horseNames.count == visit.visitHorses.count else {
                throw TodayProjectionError.invalidVisit
            }
            let resolvedCount = visit.visitHorses.filter {
                VisitOutcome(rawValue: $0.outcomeRawValue) != .pending
            }.count
            return TodayVisitSummary(
                id: visit.persistentModelID,
                appointmentID: appointment.persistentModelID,
                startedAt: visit.startedAt,
                serviceLocationName: location,
                serviceLocationAddress: TextNormalization.optional(
                    visit.serviceLocationAddressSnapshot ?? ""
                ),
                horseNames: horseNames,
                resolvedHorseCount: resolvedCount,
                totalHorseCount: horseNames.count
            )
        }.sorted { left, right in
            if left.startedAt != right.startedAt { return left.startedAt < right.startedAt }
            return String(describing: left.id) < String(describing: right.id)
        }
    }

    private func invoiceCandidates(
        in context: ModelContext
    ) throws -> [TodayInvoiceCandidate] {
        let clients = try context.fetch(
            FetchDescriptor<Client>(
                sortBy: [SortDescriptor(\.name, comparator: .localizedStandard)]
            )
        )
        return try clients.compactMap { client in
            guard let firstChoice = try InvoiceEligibilityRules.choices(
                for: client.persistentModelID,
                in: context
            ).first else {
                return nil
            }
            return TodayInvoiceCandidate(
                clientID: client.persistentModelID,
                clientName: client.name,
                workDate: firstChoice.visitDate
            )
        }.sorted { left, right in
            if left.workDate != right.workDate { return left.workDate < right.workDate }
            return String(describing: left.clientID)
                < String(describing: right.clientID)
        }
    }

    private func unpaidInvoiceSummaries(
        in context: ModelContext
    ) throws -> [TodayUnpaidInvoiceSummary] {
        let unpaid = InvoiceStatus.unpaid.rawValue
        return try context.fetch(
            FetchDescriptor<Invoice>(
                predicate: #Predicate { $0.statusRawValue == unpaid },
                sortBy: [SortDescriptor(\.invoiceDate)]
            )
        ).map {
            TodayUnpaidInvoiceSummary(
                id: $0.persistentModelID,
                number: $0.number,
                clientName: $0.clientNameSnapshot,
                invoiceDate: $0.invoiceDate
            )
        }.sorted { left, right in
            if left.invoiceDate != right.invoiceDate {
                return left.invoiceDate < right.invoiceDate
            }
            return String(describing: left.id) < String(describing: right.id)
        }
    }

    private func appointmentOrder(
        _ left: TodayAppointmentSummary,
        _ right: TodayAppointmentSummary
    ) -> Bool {
        if left.startDate != right.startDate { return left.startDate < right.startDate }
        return String(describing: left.id) < String(describing: right.id)
    }
}

private enum TodayProjectionError: Error {
    case invalidBusinessProfile
    case invalidAppointment
    case invalidVisit
}
