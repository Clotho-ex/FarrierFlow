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
    let serviceLocationID: PersistentIdentifier
    let serviceLocationName: String
    let serviceLocationAddress: String?
    let horseNames: [String]
    let horseIDs: [PersistentIdentifier]
    let state: TodayAppointmentState

    func heading(at now: Date) -> LocalizedStringResource {
        now >= startDate ? "Due Now" : "Next Appointment"
    }
}

nonisolated struct TodayStopSummary: Hashable, Identifiable {
    struct ID: Hashable {
        let serviceLocationID: PersistentIdentifier
        let startDate: Date
        let state: TodayAppointmentState
    }

    let id: ID
    let appointments: [TodayAppointmentSummary]

    var horseNames: [String] {
        var seen = Set<PersistentIdentifier>()
        return appointments.flatMap { appointment in
            zip(appointment.horseIDs, appointment.horseNames).compactMap { id, name in
                seen.insert(id).inserted ? name : nil
            }
        }.sorted(using: String.StandardComparator(.localizedStandard))
    }

    static func grouped(_ appointments: [TodayAppointmentSummary]) -> [Self] {
        var order: [ID] = []
        var groups: [ID: [TodayAppointmentSummary]] = [:]
        for appointment in appointments {
            // Only co-locate exact record identities and times; different work states stay explicit.
            let key = ID(
                serviceLocationID: appointment.serviceLocationID,
                startDate: appointment.startDate,
                state: appointment.state
            )
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(appointment)
        }
        return order.map { Self(id: $0, appointments: groups[$0, default: []]) }
    }
}

nonisolated enum TodayAppointmentState: Hashable {
    case scheduled
    case inProgress
    case completed

    var localizedTitle: LocalizedStringResource {
        switch self {
        case .scheduled:
            "Scheduled"
        case .inProgress:
            "In Progress"
        case .completed:
            "Work Complete"
        }
    }
}

nonisolated struct TodayHorseSummary: Equatable {
    let visibleHorseNames: [String]
    let remainingHorseCount: Int

    init(horseNames: [String]) {
        visibleHorseNames = Array(horseNames.prefix(2))
        remainingHorseCount = max(0, horseNames.count - visibleHorseNames.count)
    }
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
    let visitID: PersistentIdentifier
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
    case addHorse(PersistentIdentifier?)
    case createInvoice(TodayInvoiceCandidate)
    case reviewInvoice(TodayUnpaidInvoiceSummary)
    case scheduleAppointment
}

nonisolated enum TodayEmptyState: Equatable {
    case addClient
    case addHorse
    case noAppointments
    case noStops(nextAppointment: Date?)
    case allDone
}

@MainActor
@Observable
final class TodayModel {
    private(set) var loadState: TodayLoadState = .loading
    private(set) var businessName = ""
    private(set) var primaryAction: TodayPrimaryAction = .scheduleAppointment
    private(set) var remainingAppointments: [TodayAppointmentSummary] = []
    private(set) var featuredStop: TodayStopSummary?
    private(set) var remainingStops: [TodayStopSummary] = []
    private(set) var emptyState: TodayEmptyState?
    private(set) var dayIsComplete = false
    var alert: FeatureAlert?

    func load(in context: ModelContext, now: Date, calendar: Calendar) {
        loadState = .loading
        alert = nil
        do {
            businessName = try validBusinessName(in: context)
            let appointments = try appointmentSummaries(
                in: context,
                now: now,
                calendar: calendar
            )
            dayIsComplete = !appointments.isEmpty && appointments.allSatisfy { $0.state == .completed }

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
            } else if try context.fetchCount(FetchDescriptor<Horse>()) == 0 {
                var clients = FetchDescriptor<Client>()
                clients.fetchLimit = 2
                let choices = try context.fetch(clients)
                primaryAction = .addHorse(choices.count == 1 ? choices.first?.persistentModelID : nil)
                remainingAppointments = appointments
            } else {
                primaryAction = .scheduleAppointment
                remainingAppointments = appointments
            }

            let stops = TodayStopSummary.grouped(appointments)
            if case .openAppointment(let appointment) = primaryAction {
                featuredStop = stops.first { $0.appointments.contains { $0.id == appointment.id } }
            } else {
                featuredStop = nil
            }
            let featuredIDs = Set(featuredStop?.appointments.map(\.id) ?? [])
            remainingStops = TodayStopSummary.grouped(
                remainingAppointments.filter { !featuredIDs.contains($0.id) }
            )
            switch primaryAction {
            case .addClient:
                emptyState = .addClient
            case .addHorse:
                emptyState = .addHorse
            case .scheduleAppointment:
                emptyState = try idleState(in: context, now: now, calendar: calendar)
            default:
                emptyState = nil
            }
            loadState = .loaded
        } catch {
            businessName = ""
            primaryAction = .scheduleAppointment
            remainingAppointments = []
            featuredStop = nil
            remainingStops = []
            emptyState = nil
            dayIsComplete = false
            loadState = .failed
        }
    }

    private func idleState(in context: ModelContext, now: Date, calendar: Calendar) throws -> TodayEmptyState {
        if dayIsComplete { return .allDone }
        let nextDay = CalendarRules.dayInterval(containing: now, calendar: calendar).end
        var future = FetchDescriptor<Appointment>(
            predicate: #Predicate { $0.startDate >= nextDay && $0.visit == nil },
            sortBy: [SortDescriptor(\.startDate)]
        )
        future.fetchLimit = 1
        if let next = try context.fetch(future).first {
            return .noStops(nextAppointment: next.startDate)
        }
        return try context.fetchCount(FetchDescriptor<Appointment>()) == 0
            ? .noAppointments : .noStops(nextAppointment: nil)
    }

    func remainingSectionTitle(at now: Date) -> LocalizedStringResource {
        if remainingStops.contains(where: {
            $0.id.state != .completed && $0.id.startDate <= now
        }) {
            return "Remaining Today"
        }
        switch primaryAction {
        case .openAppointment(let appointment):
            return remainingStops.contains {
                $0.id.state != .completed && $0.id.startDate <= appointment.startDate
            } ? "Other Stops" : "Later Today"
        case .resumeVisit:
            return "Other Stops"
        default:
            return "Today’s Stops"
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
        return try appointments.map(TodayAppointmentSummary.project).sorted(by: appointmentOrder)
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
                visitID: firstChoice.id,
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
        return try context.fetch(
            FetchDescriptor<Invoice>(
                sortBy: [SortDescriptor(\.invoiceDate)]
            )
        ).compactMap {
            let summary = try InvoiceProjection.summary(from: $0, locale: .current)
            guard summary.status == .unpaid else {
                return nil
            }
            return TodayUnpaidInvoiceSummary(
                id: $0.persistentModelID,
                number: $0.number,
                clientName: summary.clientName,
                invoiceDate: summary.invoiceDate
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

extension TodayAppointmentSummary {
    @MainActor
    static func project(_ appointment: Appointment) throws -> Self {
        guard
            let barn = appointment.barn,
            let barnName = TextNormalization.required(barn.name)
        else {
            throw TodayProjectionError.invalidAppointment
        }
        let horses = appointment.appointmentHorses.compactMap(\.horse)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let horseNames = horses.compactMap { TextNormalization.required($0.name) }
        guard !horseNames.isEmpty, horseNames.count == appointment.appointmentHorses.count else {
            throw TodayProjectionError.invalidAppointment
        }
        return TodayAppointmentSummary(
            id: appointment.persistentModelID,
            startDate: appointment.startDate,
            serviceLocationID: barn.persistentModelID,
            serviceLocationName: barnName,
            serviceLocationAddress: TextNormalization.optional(barn.address ?? ""),
            horseNames: horseNames,
            horseIDs: horses.map(\.persistentModelID),
            state: appointment.visit.map { $0.completedAt == nil ? .inProgress : .completed } ?? .scheduled
        )
    }
}
