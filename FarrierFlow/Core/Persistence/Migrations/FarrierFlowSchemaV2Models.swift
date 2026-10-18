// Historical V2 model snapshot. Keep immutable for on-disk migration.
import Foundation
import SwiftData

extension FarrierFlowSchemaV2 {
    @Model
    final class Appointment {
        var startDate: Date
        var notes: String?
        var expectedDurationMinutes: Int?
        var barn: Barn?

        @Relationship(
            deleteRule: .cascade,
            minimumModelCount: 1,
            inverse: \AppointmentHorse.appointment
        )
        var appointmentHorses: [AppointmentHorse] = []

        @Relationship(deleteRule: .deny, inverse: \Visit.appointment)
        var visit: Visit?

        init(
            startDate: Date,
            notes: String? = nil,
            expectedDurationMinutes: Int? = nil,
            barn: Barn
        ) {
            self.startDate = startDate
            self.notes = notes
            self.expectedDurationMinutes = expectedDurationMinutes
            self.barn = barn
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class AppointmentHorse {
        var appointment: Appointment?
        var horse: Horse?

        init(appointment: Appointment, horse: Horse) {
            self.appointment = appointment
            self.horse = horse
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class Barn {
        var name: String
        var address: String?
        var contactNotes: String?

        @Relationship(deleteRule: .deny, inverse: \Horse.currentBarn)
        var horses: [Horse] = []

        @Relationship(deleteRule: .deny, inverse: \Appointment.barn)
        var appointments: [Appointment] = []

        @Relationship(deleteRule: .deny, inverse: \Visit.barn)
        var visits: [Visit] = []

        init(
            name: String,
            address: String? = nil,
            contactNotes: String? = nil
        ) {
            self.name = name
            self.address = address
            self.contactNotes = contactNotes
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class BusinessProfile {
        var name: String
        var phone: String?
        var email: String?
        var address: String?
        var defaultInvoiceNote: String?
        var defaultAppointmentDurationMinutes: Int?
        var defaultInvoiceDueDays: Int?
        var nextInvoiceNumber: Int64
        var currencyCode: String = "USD"

        init(
            name: String,
            phone: String? = nil,
            email: String? = nil,
            address: String? = nil,
            defaultInvoiceNote: String? = nil,
            defaultAppointmentDurationMinutes: Int? = nil,
            defaultInvoiceDueDays: Int? = 14,
            nextInvoiceNumber: Int64 = 1,
            currencyCode: String = "USD"
        ) {
            self.name = name
            self.phone = phone
            self.email = email
            self.address = address
            self.defaultInvoiceNote = defaultInvoiceNote
            self.defaultAppointmentDurationMinutes = defaultAppointmentDurationMinutes
            self.defaultInvoiceDueDays = defaultInvoiceDueDays
            self.nextInvoiceNumber = nextInvoiceNumber
            self.currencyCode = currencyCode
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class Client {
        var name: String
        var phone: String?
        var email: String?
        var notes: String?

        @Relationship(deleteRule: .deny, inverse: \Horse.client)
        var horses: [Horse] = []

        @Relationship(deleteRule: .deny, inverse: \Invoice.client)
        var invoices: [Invoice] = []

        init(
            name: String,
            phone: String? = nil,
            email: String? = nil,
            notes: String? = nil
        ) {
            self.name = name
            self.phone = phone
            self.email = email
            self.notes = notes
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class Horse {
        var name: String
        var safetyNotes: String?
        var appointmentIntervalWeeks: Int = 6
        var client: Client?
        var currentBarn: Barn?

        @Relationship(deleteRule: .deny, inverse: \AppointmentHorse.horse)
        var appointmentHorses: [AppointmentHorse] = []

        @Relationship(deleteRule: .deny, inverse: \VisitHorse.horse)
        var visitHorses: [VisitHorse] = []

        var defaultService: Service?

        init(
            name: String,
            safetyNotes: String? = nil,
            appointmentIntervalWeeks: Int = 6,
            client: Client,
            currentBarn: Barn,
            defaultService: Service? = nil
        ) {
            self.name = name
            self.safetyNotes = safetyNotes
            self.appointmentIntervalWeeks = appointmentIntervalWeeks
            self.client = client
            self.currentBarn = currentBarn
            self.defaultService = defaultService
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class Invoice {
        @Attribute(.unique) private(set) var number: Int64
        private(set) var invoiceDate: Date
        private(set) var dueDate: Date?
        private(set) var note: String?
        private(set) var statusRawValue: String
        private(set) var clientNameSnapshot: String
        private(set) var clientPhoneSnapshot: String?
        private(set) var clientEmailSnapshot: String?
        private(set) var businessNameSnapshot: String
        private(set) var businessPhoneSnapshot: String?
        private(set) var businessEmailSnapshot: String?
        private(set) var businessAddressSnapshot: String?
        private(set) var currencyCode: String
        private(set) var client: Client?

        @Relationship(
            deleteRule: .cascade,
            minimumModelCount: 1,
            inverse: \InvoiceVisit.invoice
        )
        var invoiceVisits: [InvoiceVisit] = []

        @Relationship(deleteRule: .cascade, inverse: \Payment.invoice)
        private(set) var payments: [Payment] = []

        init(
            number: Int64,
            invoiceDate: Date,
            dueDate: Date? = nil,
            note: String? = nil,
            clientNameSnapshot: String,
            clientPhoneSnapshot: String? = nil,
            clientEmailSnapshot: String? = nil,
            businessNameSnapshot: String,
            businessPhoneSnapshot: String? = nil,
            businessEmailSnapshot: String? = nil,
            businessAddressSnapshot: String? = nil,
            currencyCode: String = "USD",
            client: Client
        ) {
            self.number = number
            self.invoiceDate = invoiceDate
            self.dueDate = dueDate
            self.note = note
            statusRawValue = InvoiceStatus.unpaid.rawValue
            self.clientNameSnapshot = clientNameSnapshot
            self.clientPhoneSnapshot = clientPhoneSnapshot
            self.clientEmailSnapshot = clientEmailSnapshot
            self.businessNameSnapshot = businessNameSnapshot
            self.businessPhoneSnapshot = businessPhoneSnapshot
            self.businessEmailSnapshot = businessEmailSnapshot
            self.businessAddressSnapshot = businessAddressSnapshot
            self.currencyCode = currencyCode
            self.client = client
        }

        func recordCompletedPayment(_ payment: Payment) throws {
            guard statusRawValue == InvoiceStatus.unpaid.rawValue else {
                throw InvoicePaymentError.invoiceAlreadyPaid
            }
            guard payment.invoice === self,
                  payments.isEmpty || (payments.count == 1 && payments.first === payment)
            else {
                throw InvoicePaymentError.invalidPaymentEvidence
            }
            if payments.isEmpty {
                payments.append(payment)
            }
            statusRawValue = InvoiceStatus.paid.rawValue
        }

        func removeCompletedPayment() throws -> Payment {
            guard statusRawValue == InvoiceStatus.paid.rawValue, payments.count == 1,
                  let payment = payments.first else {
                throw InvoicePaymentError.invoiceAlreadyUnpaid
            }
            payments.removeAll()
            statusRawValue = InvoiceStatus.unpaid.rawValue
            return payment
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class InvoiceLineItem {
        private(set) var horseNameSnapshot: String
        private(set) var serviceNameSnapshot: String
        private(set) var amountMinorUnits: Int64
        private(set) var currencyCode: String
        private(set) var invoiceVisit: InvoiceVisit?
        private(set) var sourceWorkItem: WorkItem?

        init(
            horseNameSnapshot: String,
            serviceNameSnapshot: String,
            amountMinorUnits: Int64,
            currencyCode: String = "USD",
            invoiceVisit: InvoiceVisit,
            sourceWorkItem: WorkItem
        ) {
            self.horseNameSnapshot = horseNameSnapshot
            self.serviceNameSnapshot = serviceNameSnapshot
            self.amountMinorUnits = amountMinorUnits
            self.currencyCode = currencyCode
            self.invoiceVisit = invoiceVisit
            self.sourceWorkItem = sourceWorkItem
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class InvoiceVisit {
        private(set) var visitDateSnapshot: Date
        private(set) var serviceLocationNameSnapshot: String
        private(set) var serviceLocationAddressSnapshot: String?
        private(set) var invoice: Invoice?
        private(set) var sourceVisit: Visit?

        @Relationship(
            deleteRule: .cascade,
            minimumModelCount: 1,
            inverse: \InvoiceLineItem.invoiceVisit
        )
        var lineItems: [InvoiceLineItem] = []

        init(
            visitDateSnapshot: Date,
            serviceLocationNameSnapshot: String,
            serviceLocationAddressSnapshot: String? = nil,
            invoice: Invoice,
            sourceVisit: Visit
        ) {
            self.visitDateSnapshot = visitDateSnapshot
            self.serviceLocationNameSnapshot = serviceLocationNameSnapshot
            self.serviceLocationAddressSnapshot = serviceLocationAddressSnapshot
            self.invoice = invoice
            self.sourceVisit = sourceVisit
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class Payment {
        @Attribute(.unique) private(set) var id: UUID
        private(set) var amountMinorUnits: Int64
        private(set) var currencyCode: String
        private(set) var receivedAt: Date
        private(set) var methodRawValue: String
        private(set) var sourceRawValue: String
        private(set) var otherDescription: String?
        private(set) var reference: String?
        private(set) var note: String?
        private(set) var invoice: Invoice?

        var method: PaymentMethod? { PaymentMethod(rawValue: methodRawValue) }
        var source: PaymentRecordSource? { PaymentRecordSource(rawValue: sourceRawValue) }

        init(
            id: UUID = UUID(),
            amountMinorUnits: Int64,
            currencyCode: String,
            receivedAt: Date,
            method: PaymentMethod,
            source: PaymentRecordSource = .manual,
            otherDescription: String? = nil,
            reference: String? = nil,
            note: String? = nil,
            invoice: Invoice
        ) {
            self.id = id
            self.amountMinorUnits = amountMinorUnits
            self.currencyCode = currencyCode
            self.receivedAt = receivedAt
            methodRawValue = method.rawValue
            sourceRawValue = source.rawValue
            self.otherDescription = otherDescription
            self.reference = reference
            self.note = note
            self.invoice = invoice
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class Photograph {
        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var pixelWidth: Int
        var pixelHeight: Int
        var byteCount: Int64
        var visitHorse: VisitHorse?

        init(
            id: UUID,
            createdAt: Date,
            pixelWidth: Int,
            pixelHeight: Int,
            byteCount: Int64,
            visitHorse: VisitHorse
        ) {
            self.id = id
            self.createdAt = createdAt
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.byteCount = byteCount
            self.visitHorse = visitHorse
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class Service {
        var name: String
        var defaultAmountMinorUnits: Int64
        var currencyCode: String
        var isArchived: Bool

        @Relationship(deleteRule: .deny, inverse: \Horse.defaultService)
        var horsesUsingAsDefault: [Horse] = []

        @Relationship(deleteRule: .deny, inverse: \WorkItem.service)
        var workItems: [WorkItem] = []

        init(
            name: String,
            defaultAmountMinorUnits: Int64,
            currencyCode: String = "USD",
            isArchived: Bool = false
        ) {
            self.name = name
            self.defaultAmountMinorUnits = defaultAmountMinorUnits
            self.currencyCode = currencyCode
            self.isArchived = isArchived
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class Visit {
        var startedAt: Date
        var completedAt: Date?
        var serviceLocationNameSnapshot: String
        var serviceLocationAddressSnapshot: String?
        var appointment: Appointment?
        var barn: Barn?

        @Relationship(
            deleteRule: .cascade,
            minimumModelCount: 1,
            inverse: \VisitHorse.visit
        )
        var visitHorses: [VisitHorse] = []

        @Relationship(deleteRule: .deny, inverse: \InvoiceVisit.sourceVisit)
        var invoiceVisits: [InvoiceVisit] = []

        init(
            startedAt: Date,
            completedAt: Date? = nil,
            serviceLocationNameSnapshot: String,
            serviceLocationAddressSnapshot: String? = nil,
            appointment: Appointment,
            barn: Barn
        ) {
            self.startedAt = startedAt
            self.completedAt = completedAt
            self.serviceLocationNameSnapshot = serviceLocationNameSnapshot
            self.serviceLocationAddressSnapshot = serviceLocationAddressSnapshot
            self.appointment = appointment
            self.barn = barn
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class VisitHorse {
        var outcomeRawValue: String
        var workNotes: String?
        var visit: Visit?
        var horse: Horse?

        @Relationship(deleteRule: .cascade, inverse: \Photograph.visitHorse)
        var photographs: [Photograph] = []

        @Relationship(deleteRule: .cascade, inverse: \WorkItem.visitHorse)
        var workItems: [WorkItem] = []

        init(
            outcomeRawValue: String = "pending",
            workNotes: String? = nil,
            visit: Visit,
            horse: Horse
        ) {
            self.outcomeRawValue = outcomeRawValue
            self.workNotes = workNotes
            self.visit = visit
            self.horse = horse
        }
    }
}

extension FarrierFlowSchemaV2 {
    @Model
    final class WorkItem {
        var serviceNameSnapshot: String
        var amountMinorUnits: Int64
        var currencyCode: String
        var service: Service?
        var visitHorse: VisitHorse?

        @Relationship(deleteRule: .deny, inverse: \InvoiceLineItem.sourceWorkItem)
        var invoiceLineItem: InvoiceLineItem?

        init(
            serviceNameSnapshot: String,
            amountMinorUnits: Int64,
            currencyCode: String = "USD",
            service: Service,
            visitHorse: VisitHorse
        ) {
            self.serviceNameSnapshot = serviceNameSnapshot
            self.amountMinorUnits = amountMinorUnits
            self.currencyCode = currencyCode
            self.service = service
            self.visitHorse = visitHorse
        }
    }
}
