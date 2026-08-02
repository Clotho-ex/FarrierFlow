import Foundation
import SwiftData
@testable import FarrierFlow

enum ModelFixtures {
    static func makeClient(name: String = "Alex Carter") -> Client {
        Client(name: name)
    }

    static func makeBarn(name: String = "North Field") -> Barn {
        Barn(name: name)
    }

    static func makeHorse(
        name: String = "Milo",
        client: Client,
        barn: Barn
    ) -> Horse {
        Horse(name: name, client: client, currentBarn: barn)
    }

    static func makeAppointment(
        startDate: Date = .now,
        barn: Barn,
        horses: [Horse],
        in context: ModelContext
    ) -> Appointment {
        let appointment = Appointment(startDate: startDate, barn: barn)
        context.insert(appointment)
        barn.appointments.append(appointment)
        for horse in horses {
            let appointmentHorse = AppointmentHorse(
                appointment: appointment,
                horse: horse
            )
            context.insert(appointmentHorse)
            appointment.appointmentHorses.append(appointmentHorse)
            horse.appointmentHorses.append(appointmentHorse)
        }
        return appointment
    }

    static func makeVisit(
        startedAt: Date = .now,
        completedAt: Date? = nil,
        appointment: Appointment,
        in context: ModelContext
    ) -> Visit {
        precondition(appointment.visit == nil)
        guard let barn = appointment.barn else {
            preconditionFailure("A Visit fixture requires an Appointment barn.")
        }

        let visit = Visit(
            startedAt: startedAt,
            completedAt: completedAt,
            serviceLocationNameSnapshot: barn.name,
            serviceLocationAddressSnapshot: barn.address,
            appointment: appointment,
            barn: barn
        )
        context.insert(visit)
        appointment.visit = visit
        barn.visits.append(visit)

        for appointmentHorse in appointment.appointmentHorses {
            guard let horse = appointmentHorse.horse else {
                preconditionFailure("A Visit fixture requires every AppointmentHorse to have a Horse.")
            }
            let visitHorse = VisitHorse(visit: visit, horse: horse)
            context.insert(visitHorse)
            visit.visitHorses.append(visitHorse)
            horse.visitHorses.append(visitHorse)
        }
        return visit
    }

    static func makeService(
        name: String = "Front Shoes",
        defaultAmountMinorUnits: Int64 = 12_500,
        currencyCode: String = "USD",
        isArchived: Bool = false,
        in context: ModelContext
    ) -> Service {
        let service = Service(
            name: name,
            defaultAmountMinorUnits: defaultAmountMinorUnits,
            currencyCode: currencyCode,
            isArchived: isArchived
        )
        context.insert(service)
        return service
    }

    static func makeWorkItem(
        service: Service,
        visitHorse: VisitHorse,
        serviceNameSnapshot: String? = nil,
        amountMinorUnits: Int64? = nil,
        currencyCode: String? = nil,
        in context: ModelContext
    ) -> WorkItem {
        let workItem = WorkItem(
            serviceNameSnapshot: serviceNameSnapshot ?? service.name,
            amountMinorUnits: amountMinorUnits ?? service.defaultAmountMinorUnits,
            currencyCode: currencyCode ?? service.currencyCode,
            service: service,
            visitHorse: visitHorse
        )
        context.insert(workItem)
        service.workItems.append(workItem)
        visitHorse.workItems.append(workItem)
        return workItem
    }

    static func makeBusinessProfile(
        name: String = "Alex Carter Farrier",
        phone: String? = "555-0100",
        email: String? = "alex@example.com",
        address: String? = "1 Main Street",
        defaultInvoiceNote: String? = "Thank you.",
        defaultAppointmentDurationMinutes: Int? = nil,
        defaultInvoiceDueDays: Int? = 14,
        nextInvoiceNumber: Int64 = 1,
        in context: ModelContext
    ) -> BusinessProfile {
        let profile = BusinessProfile(
            name: name,
            phone: phone,
            email: email,
            address: address,
            defaultInvoiceNote: defaultInvoiceNote,
            defaultAppointmentDurationMinutes: defaultAppointmentDurationMinutes,
            defaultInvoiceDueDays: defaultInvoiceDueDays,
            nextInvoiceNumber: nextInvoiceNumber
        )
        context.insert(profile)
        return profile
    }

    static func makeInvoice(
        number: Int64,
        client: Client,
        businessProfile: BusinessProfile,
        invoiceDate: Date = Date(timeIntervalSinceReferenceDate: 500),
        dueDate: Date? = Date(timeIntervalSinceReferenceDate: 600),
        note: String? = "Thank you.",
        status: InvoiceStatus = .unpaid,
        paidAt: Date? = nil,
        in context: ModelContext
    ) -> Invoice {
        let invoice = Invoice(
            number: number,
            invoiceDate: invoiceDate,
            dueDate: dueDate,
            note: note,
            statusRawValue: status.rawValue,
            paidAt: paidAt,
            clientNameSnapshot: client.name,
            clientPhoneSnapshot: client.phone,
            clientEmailSnapshot: client.email,
            businessNameSnapshot: businessProfile.name,
            businessPhoneSnapshot: businessProfile.phone,
            businessEmailSnapshot: businessProfile.email,
            businessAddressSnapshot: businessProfile.address,
            client: client
        )
        context.insert(invoice)
        client.invoices.append(invoice)
        return invoice
    }

    static func makeInvoiceVisit(
        invoice: Invoice,
        sourceVisit: Visit,
        in context: ModelContext
    ) -> InvoiceVisit {
        let invoiceVisit = InvoiceVisit(
            visitDateSnapshot: sourceVisit.startedAt,
            serviceLocationNameSnapshot: sourceVisit.serviceLocationNameSnapshot,
            serviceLocationAddressSnapshot: sourceVisit.serviceLocationAddressSnapshot,
            invoice: invoice,
            sourceVisit: sourceVisit
        )
        context.insert(invoiceVisit)
        invoice.invoiceVisits.append(invoiceVisit)
        sourceVisit.invoiceVisits.append(invoiceVisit)
        return invoiceVisit
    }

    static func makeInvoiceLineItem(
        invoiceVisit: InvoiceVisit,
        sourceWorkItem: WorkItem,
        in context: ModelContext
    ) throws -> InvoiceLineItem {
        guard let horse = sourceWorkItem.visitHorse?.horse else {
            throw DomainGraphViolation.workItemMissingVisitHorse
        }
        let lineItem = InvoiceLineItem(
            horseNameSnapshot: horse.name,
            serviceNameSnapshot: sourceWorkItem.serviceNameSnapshot,
            amountMinorUnits: sourceWorkItem.amountMinorUnits,
            currencyCode: sourceWorkItem.currencyCode,
            invoiceVisit: invoiceVisit,
            sourceWorkItem: sourceWorkItem
        )
        context.insert(lineItem)
        invoiceVisit.lineItems.append(lineItem)
        sourceWorkItem.invoiceLineItem = lineItem
        return lineItem
    }
}
