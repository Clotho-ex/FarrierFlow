import Foundation
import SwiftData

enum RecordDeletionTarget: Hashable {
    case client(PersistentIdentifier), horse(PersistentIdentifier), barn(PersistentIdentifier)
    case service(PersistentIdentifier), appointment(PersistentIdentifier), visit(PersistentIdentifier)
    case invoice(PersistentIdentifier), workItem(PersistentIdentifier)
}

enum RecordDeletionError: Error {
    case unavailable, dependenciesChanged
}

struct RecordDeletionImpact: Equatable {
    let target: RecordDeletionTarget
    let recordIDs: Set<PersistentIdentifier>
    let referenceIDs: Set<PersistentIdentifier>
    let horseCount: Int
    let appointmentCount: Int
    let visitCount: Int
    let workCount: Int
    let photoIDs: Set<UUID>

    var warning: LocalizedStringResource {
        switch target {
        case .client:
            "Deletes this client, its horses and their recorded work and photos. Removes their appointment and visit memberships; empty appointments and visits are deleted. Saved invoices are kept. This cannot be undone."
        case .horse:
            "Deletes this horse and its recorded work and photos. Removes it from appointments and visits; empty appointments and visits are deleted. Saved invoices are kept. This cannot be undone."
        case .barn:
            "Deletes this service location, its horses and related appointments, visits, recorded work and photos. Saved invoices are kept. This cannot be undone."
        case .service:
            "Deletes this service and its recorded work. Clears horse defaults and scheduled service choices. Saved invoices and photos are kept. This cannot be undone."
        case .appointment:
            "Deletes this appointment and any linked visit, recorded work and photos. Horses, clients and saved invoices are kept. This cannot be undone."
        case .visit:
            "Deletes this visit, its appointment, recorded work and photos. Horses, clients and saved invoices are kept. This cannot be undone."
        case .invoice:
            "Deletes this invoice and any recorded payment. Recorded work and photos are kept. This cannot be undone."
        case .workItem:
            "Deletes this recorded service. Saved invoices and photos are kept. This cannot be undone."
        }
    }
}

@MainActor
struct RecordDeletionPlan {
    private let target: RecordDeletionTarget
    private var clients: [PersistentIdentifier: Client] = [:]
    private var horses: [PersistentIdentifier: Horse] = [:]
    private var barns: [PersistentIdentifier: Barn] = [:]
    private var services: [PersistentIdentifier: Service] = [:]
    private var appointments: [PersistentIdentifier: Appointment] = [:]
    private var memberships: [PersistentIdentifier: AppointmentHorse] = [:]
    private var visits: [PersistentIdentifier: Visit] = [:]
    private var visitHorses: [PersistentIdentifier: VisitHorse] = [:]
    private var work: [PersistentIdentifier: WorkItem] = [:]
    private var photos: [PersistentIdentifier: Photograph] = [:]
    private var invoices: [PersistentIdentifier: Invoice] = [:]
    private var heldWork: [PersistentIdentifier: WorkItem] = [:]
    private var affectedAppointments: [PersistentIdentifier: Appointment] = [:]
    private var affectedVisits: [PersistentIdentifier: Visit] = [:]

    init(target: RecordDeletionTarget, in context: ModelContext) throws {
        self.target = target
        switch target {
        case .client(let id):
            let record: Client = try Self.resolve(id, in: context)
            clients[id] = record
            for horse in record.horses { add(horse) }
        case .horse(let id): add(try Self.resolve(id, in: context) as Horse)
        case .barn(let id):
            let record: Barn = try Self.resolve(id, in: context)
            barns[id] = record
            for horse in record.horses { add(horse) }
            for appointment in record.appointments { add(appointment) }
            for visit in record.visits { add(visit) }
        case .service(let id):
            let record: Service = try Self.resolve(id, in: context)
            services[id] = record
            for item in record.workItems { add(item) }
        case .appointment(let id): add(try Self.resolve(id, in: context) as Appointment)
        case .visit(let id): add(try Self.resolve(id, in: context) as Visit)
        case .workItem(let id): add(try Self.resolve(id, in: context) as WorkItem)
        case .invoice(let id):
            let invoice: Invoice = try Self.resolve(id, in: context)
            invoices[id] = invoice
            if let invoiceID = invoice.syncID {
                for item in try context.fetch(FetchDescriptor<WorkItem>()) where item.billingHoldID == invoiceID {
                    heldWork[item.persistentModelID] = item
                }
            }
        }
        // Removing the last horse removes its empty physical visit/appointment.
        for appointment in Array(affectedAppointments.values) where appointment.appointmentHorses.allSatisfy({ memberships[$0.persistentModelID] != nil }) {
            add(appointment)
        }
        for visit in Array(affectedVisits.values) where visit.visitHorses.allSatisfy({ visitHorses[$0.persistentModelID] != nil }) {
            add(visit)
        }
    }

    var impact: RecordDeletionImpact {
        let groups = invoices.values.flatMap(\.invoiceVisits)
        let lines = groups.flatMap(\.lineItems)
        var ids = Set(clients.keys).union(horses.keys).union(barns.keys).union(services.keys)
            .union(appointments.keys).union(memberships.keys).union(visits.keys)
            .union(visitHorses.keys).union(work.keys).union(photos.keys).union(invoices.keys)
        ids.formUnion(groups.map(\.persistentModelID))
        ids.formUnion(lines.map(\.persistentModelID))
        ids.formUnion(invoices.values.flatMap(\.payments).map(\.persistentModelID))
        var references = Set(services.values.flatMap(\.horsesUsingAsDefault).map(\.persistentModelID))
        references.formUnion(services.values.flatMap(\.plannedAppointments).map(\.persistentModelID))
        references.formUnion(clients.values.flatMap(\.invoices).map(\.persistentModelID))
        references.formUnion(work.values.compactMap(\.invoiceLineItem).map(\.persistentModelID))
        references.formUnion(visits.values.flatMap(\.invoiceVisits).map(\.persistentModelID))
        references.formUnion(heldWork.keys)
        return RecordDeletionImpact(
            target: target, recordIDs: ids, referenceIDs: references,
            horseCount: horses.count, appointmentCount: appointments.count,
            visitCount: visits.count, workCount: work.count, photoIDs: Set(photos.values.map(\.id))
        )
    }

    static func execute(
        _ target: RecordDeletionTarget,
        confirming expected: RecordDeletionImpact? = nil,
        in context: ModelContext,
        saving: @MainActor (ModelContext) throws -> Void = { try DomainGraphValidator.save($0) }
    ) throws {
        do {
            let plan = try RecordDeletionPlan(target: target, in: context)
            guard expected == nil || expected == plan.impact else { throw RecordDeletionError.dependenciesChanged }
            try plan.apply(in: context)
            try saving(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private mutating func add(_ horse: Horse) {
        guard horses.updateValue(horse, forKey: horse.persistentModelID) == nil else { return }
        for member in horse.appointmentHorses { add(member) }
        for member in horse.visitHorses { add(member) }
    }

    private mutating func add(_ appointment: Appointment) {
        guard appointments.updateValue(appointment, forKey: appointment.persistentModelID) == nil else { return }
        for member in appointment.appointmentHorses { add(member) }
        if let visit = appointment.visit { add(visit) }
    }

    private mutating func add(_ membership: AppointmentHorse) {
        memberships[membership.persistentModelID] = membership
        if let appointment = membership.appointment { affectedAppointments[appointment.persistentModelID] = appointment }
    }

    private mutating func add(_ visit: Visit) {
        guard visits.updateValue(visit, forKey: visit.persistentModelID) == nil else { return }
        for member in visit.visitHorses { add(member) }
        if let appointment = visit.appointment { add(appointment) }
    }

    private mutating func add(_ member: VisitHorse) {
        guard visitHorses.updateValue(member, forKey: member.persistentModelID) == nil else { return }
        if let visit = member.visit {
            affectedVisits[visit.persistentModelID] = visit
            for appointmentHorse in visit.appointment?.appointmentHorses ?? [] where appointmentHorse.horse === member.horse {
                add(appointmentHorse)
            }
        }
        for item in member.workItems { add(item) }
        for photo in member.photographs { photos[photo.persistentModelID] = photo }
    }

    private mutating func add(_ item: WorkItem) {
        work[item.persistentModelID] = item
    }

    private func apply(in context: ModelContext) throws {
        for client in clients.values {
            for invoice in client.invoices { invoice.detachClient() }
        }
        for visit in visits.values {
            for group in visit.invoiceVisits { group.detachSourceVisit() }
        }
        for item in work.values { item.invoiceLineItem?.detachSourceWorkItem() }
        for invoice in invoices.values {
            let invoiceID = invoice.syncID
            for group in invoice.invoiceVisits {
                for line in group.lineItems { line.detachSourceWorkItem() }
                group.detachSourceVisit()
            }
            if let invoiceID {
                for item in heldWork.values { item.releaseBillingHold(for: invoiceID) }
            }
            if !invoice.payments.isEmpty {
                let payment = try invoice.removeCompletedPayment()
                context.delete(payment)
            }
            invoice.detachClient()
            context.delete(invoice)
        }
        for service in services.values {
            for horse in service.horsesUsingAsDefault { horse.defaultService = nil }
            for member in service.plannedAppointments { member.plannedService = nil }
        }
        for item in work.values {
            let member = item.visitHorse
            item.service?.workItems.removeAll { $0 === item }
            member?.workItems.removeAll { $0 === item }
            item.service = nil
            item.visitHorse = nil
            context.delete(item)
            if let member, member.workItems.isEmpty, member.outcomeRawValue == VisitOutcome.serviced.rawValue {
                member.outcomeRawValue = VisitOutcome.notServiced.rawValue
                member.workNotes = nil
            }
        }
        for photo in photos.values {
            photo.visitHorse?.photographs.removeAll { $0 === photo }
            photo.visitHorse = nil
            context.delete(photo)
        }
        for member in visitHorses.values {
            member.horse?.visitHorses.removeAll { $0 === member }
            member.visit?.visitHorses.removeAll { $0 === member }
            member.horse = nil
            member.visit = nil
            context.delete(member)
        }
        for member in memberships.values {
            member.horse?.appointmentHorses.removeAll { $0 === member }
            member.appointment?.appointmentHorses.removeAll { $0 === member }
            member.plannedService = nil
            member.horse = nil
            member.appointment = nil
            context.delete(member)
        }
        for visit in visits.values {
            visit.appointment?.visit = nil
            visit.barn?.visits.removeAll { $0 === visit }
            visit.appointment = nil
            visit.barn = nil
            context.delete(visit)
        }
        for appointment in appointments.values {
            appointment.barn?.appointments.removeAll { $0 === appointment }
            appointment.barn = nil
            context.delete(appointment)
        }
        for horse in horses.values {
            horse.client?.horses.removeAll { $0 === horse }
            horse.currentBarn?.horses.removeAll { $0 === horse }
            horse.defaultService = nil
            horse.client = nil
            horse.currentBarn = nil
            context.delete(horse)
        }
        for service in services.values { context.delete(service) }
        for client in clients.values { context.delete(client) }
        for barn in barns.values { context.delete(barn) }
    }

    private static func resolve<T: PersistentModel>(_ id: PersistentIdentifier, in context: ModelContext) throws -> T {
        guard let record = try context.existingModel(T.self, for: id) else { throw RecordDeletionError.unavailable }
        return record
    }
}
