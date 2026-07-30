import Foundation
import SwiftData

nonisolated enum DomainGraphViolation: Error, Equatable {
    case horseMissingClient
    case horseMissingCurrentBarn
    case appointmentMissingBarn
    case appointmentHasNoValidHorse
    case appointmentHorseMissingAppointment
    case appointmentHorseMissingHorse
    case horseOutsideAppointmentBarn
    case duplicateHorseMembership
    case visitMissingAppointment
    case visitMissingBarn
    case visitHasNoHorse
    case visitHorseMissingVisit
    case visitHorseMissingHorse
    case duplicateVisitHorseMembership
    case visitMembershipMismatch
    case visitLocationNameMissing
    case inProgressVisitHasCompletionDate
    case completedVisitHasPendingHorse
    case completedVisitHasNoServicedHorse
    case completionPredatesStart
    case workNotesRequireServicedOutcome
    case appointmentVisitMismatch
    case photographMissingVisitHorse
    case photographInverseMismatch
    case invalidPhotographDimensions
    case invalidPhotographByteCount
    case duplicatePhotographID
    case serviceNameNotNormalized
    case serviceAmountNegative
    case serviceCurrencyInvalid
    case serviceHorseDefaultInverseMismatch
    case serviceWorkItemInverseMismatch
    case horseDefaultServiceArchived
    case horseDefaultServiceInverseMismatch
    case workItemMissingService
    case workItemMissingVisitHorse
    case workItemServiceInverseMismatch
    case workItemVisitHorseInverseMismatch
    case workItemServiceNameSnapshotNotNormalized
    case workItemAmountNegative
    case workItemCurrencyInvalid
    case duplicateWorkItemService
    case notServicedVisitHorseHasWorkItems
    case completedServicedVisitHorseHasNoWorkItems
    case workItemTotalOverflow
    case duplicateBusinessProfile
    case businessProfileMissing
    case businessProfileNameNotNormalized
    case businessProfileOptionalTextNotNormalized
    case businessProfileSequenceInvalid
    case invoiceNumberInvalid
    case duplicateInvoiceNumber
    case invoiceMissingClient
    case invoiceClientInverseMismatch
    case invoiceSnapshotNotNormalized
    case invoiceCurrencyInvalid
    case invoiceStatusInvalid
    case invoiceHasNoVisit
    case invoiceVisitMissingInvoice
    case invoiceVisitMissingSourceVisit
    case invoiceVisitInvoiceInverseMismatch
    case invoiceVisitSourceInverseMismatch
    case duplicateInvoiceVisitSource
    case invoiceVisitSnapshotNotNormalized
    case invoiceVisitHasNoLineItem
    case invoiceLineItemMissingInvoiceVisit
    case invoiceLineItemMissingSourceWorkItem
    case invoiceLineItemVisitInverseMismatch
    case invoiceLineItemWorkItemInverseMismatch
    case invoiceLineItemSourceVisitMismatch
    case invoiceLineItemSnapshotNotNormalized
    case invoiceLineItemAmountNegative
    case invoiceLineItemCurrencyInvalid
    case invoiceLineItemClientMismatch
    case duplicateInvoiceLineItemSource
    case invoiceTotalOverflow
}

@MainActor
enum DomainGraphValidator {
    static func save(_ context: ModelContext) throws {
        try validateAll(in: context)
        try context.save()
    }

    static func validateAll(in context: ModelContext) throws {
        let horses = try context.fetch(FetchDescriptor<Horse>())
        let appointments = try context.fetch(FetchDescriptor<Appointment>())
        let appointmentHorses = try context.fetch(FetchDescriptor<AppointmentHorse>())
        let visits = try context.fetch(FetchDescriptor<Visit>())
        let visitHorses = try context.fetch(FetchDescriptor<VisitHorse>())
        let photographs = try context.fetch(FetchDescriptor<Photograph>())
        let services = try context.fetch(FetchDescriptor<Service>())
        let workItems = try context.fetch(FetchDescriptor<WorkItem>())
        let businessProfiles = try context.fetch(FetchDescriptor<BusinessProfile>())
        let invoices = try context.fetch(FetchDescriptor<Invoice>())
        let invoiceVisits = try context.fetch(FetchDescriptor<InvoiceVisit>())
        let invoiceLineItems = try context.fetch(FetchDescriptor<InvoiceLineItem>())

        guard businessProfiles.count <= 1 else {
            throw DomainGraphViolation.duplicateBusinessProfile
        }

        if let businessProfile = businessProfiles.first {
            try validate(businessProfile)
        } else if !invoices.isEmpty {
            throw DomainGraphViolation.businessProfileMissing
        }

        var invoiceNumbers = Set<Int64>()
        for invoice in invoices {
            guard invoice.number > 0 else {
                throw DomainGraphViolation.invoiceNumberInvalid
            }
            guard invoiceNumbers.insert(invoice.number).inserted else {
                throw DomainGraphViolation.duplicateInvoiceNumber
            }
        }

        if
            let businessProfile = businessProfiles.first,
            let greatestNumber = invoices.map(\.number).max(),
            businessProfile.nextInvoiceNumber <= greatestNumber
        {
            throw DomainGraphViolation.businessProfileSequenceInvalid
        }

        for service in services {
            try validate(service)
        }

        for horse in horses {
            try validate(horse)
        }

        for workItem in workItems {
            try validate(workItem)
        }

        var lineItemsByInvoiceVisit = [PersistentIdentifier: [InvoiceLineItem]]()
        var billedWorkItemIDs = Set<PersistentIdentifier>()
        for lineItem in invoiceLineItems {
            try validate(lineItem)
            guard let invoiceVisit = lineItem.invoiceVisit else {
                throw DomainGraphViolation.invoiceLineItemMissingInvoiceVisit
            }
            guard
                let sourceWorkItem = lineItem.sourceWorkItem,
                billedWorkItemIDs.insert(sourceWorkItem.persistentModelID).inserted
            else {
                throw DomainGraphViolation.duplicateInvoiceLineItemSource
            }
            lineItemsByInvoiceVisit[invoiceVisit.persistentModelID, default: []].append(lineItem)
        }

        var visitsByInvoice = [PersistentIdentifier: [InvoiceVisit]]()
        for invoiceVisit in invoiceVisits {
            try validate(
                invoiceVisit,
                lineItems: lineItemsByInvoiceVisit[invoiceVisit.persistentModelID, default: []]
            )
            guard let invoice = invoiceVisit.invoice else {
                throw DomainGraphViolation.invoiceVisitMissingInvoice
            }
            visitsByInvoice[invoice.persistentModelID, default: []].append(invoiceVisit)
        }

        for invoice in invoices {
            try validate(
                invoice,
                visits: visitsByInvoice[invoice.persistentModelID, default: []]
            )
        }

        var appointmentMemberships = [PersistentIdentifier: [AppointmentHorse]]()
        for appointmentHorse in appointmentHorses {
            try validate(appointmentHorse)
            if let appointment = appointmentHorse.appointment {
                appointmentMemberships[appointment.persistentModelID, default: []]
                    .append(appointmentHorse)
            }
        }

        var visitMemberships = [PersistentIdentifier: [VisitHorse]]()
        for visitHorse in visitHorses {
            try validate(visitHorse)
            if let visit = visitHorse.visit {
                visitMemberships[visit.persistentModelID, default: []].append(visitHorse)
            }
        }

        var photographIDs = Set<UUID>()
        for photograph in photographs {
            try validate(photograph)
            guard photographIDs.insert(photograph.id).inserted else {
                throw DomainGraphViolation.duplicatePhotographID
            }
        }

        var visitsByAppointment = [PersistentIdentifier: [Visit]]()
        for visit in visits {
            if let appointment = visit.appointment {
                visitsByAppointment[appointment.persistentModelID, default: []].append(visit)
            }
            try validate(
                visit,
                memberships: visitMemberships[visit.persistentModelID, default: []],
                appointmentMemberships: &appointmentMemberships
            )
        }

        for appointment in appointments {
            try validate(
                appointment,
                memberships: appointmentMemberships[appointment.persistentModelID, default: []],
                visits: visitsByAppointment[appointment.persistentModelID, default: []]
            )
        }
    }

    static func validateInProgress(_ visit: Visit) throws {
        guard visit.completedAt == nil else {
            throw DomainGraphViolation.inProgressVisitHasCompletionDate
        }
    }

    private static func validate(_ horse: Horse) throws {
        guard horse.client != nil else {
            throw DomainGraphViolation.horseMissingClient
        }
        guard horse.currentBarn != nil else {
            throw DomainGraphViolation.horseMissingCurrentBarn
        }
        if let service = horse.defaultService {
            guard !service.isArchived else {
                throw DomainGraphViolation.horseDefaultServiceArchived
            }
            guard service.horsesUsingAsDefault.contains(where: { $0 === horse }) else {
                throw DomainGraphViolation.horseDefaultServiceInverseMismatch
            }
        }
    }

    private static func validate(_ service: Service) throws {
        guard TextNormalization.required(service.name) == service.name else {
            throw DomainGraphViolation.serviceNameNotNormalized
        }
        guard service.defaultAmountMinorUnits >= 0 else {
            throw DomainGraphViolation.serviceAmountNegative
        }
        guard service.currencyCode == "USD" else {
            throw DomainGraphViolation.serviceCurrencyInvalid
        }
        guard service.horsesUsingAsDefault.allSatisfy({ $0.defaultService === service }) else {
            throw DomainGraphViolation.serviceHorseDefaultInverseMismatch
        }
        guard service.workItems.allSatisfy({ $0.service === service }) else {
            throw DomainGraphViolation.serviceWorkItemInverseMismatch
        }
    }

    private static func validate(_ appointmentHorse: AppointmentHorse) throws {
        guard appointmentHorse.appointment != nil else {
            throw DomainGraphViolation.appointmentHorseMissingAppointment
        }
        guard appointmentHorse.horse != nil else {
            throw DomainGraphViolation.appointmentHorseMissingHorse
        }
    }

    private static func validate(_ visitHorse: VisitHorse) throws {
        guard visitHorse.visit != nil else {
            throw DomainGraphViolation.visitHorseMissingVisit
        }
        guard visitHorse.horse != nil else {
            throw DomainGraphViolation.visitHorseMissingHorse
        }
    }

    private static func validate(_ workItem: WorkItem) throws {
        guard let service = workItem.service else {
            throw DomainGraphViolation.workItemMissingService
        }
        guard let visitHorse = workItem.visitHorse else {
            throw DomainGraphViolation.workItemMissingVisitHorse
        }
        guard service.workItems.contains(where: { $0 === workItem }) else {
            throw DomainGraphViolation.workItemServiceInverseMismatch
        }
        guard visitHorse.workItems.contains(where: { $0 === workItem }) else {
            throw DomainGraphViolation.workItemVisitHorseInverseMismatch
        }
        guard TextNormalization.required(workItem.serviceNameSnapshot) == workItem.serviceNameSnapshot else {
            throw DomainGraphViolation.workItemServiceNameSnapshotNotNormalized
        }
        guard workItem.amountMinorUnits >= 0 else {
            throw DomainGraphViolation.workItemAmountNegative
        }
        guard workItem.currencyCode == "USD" else {
            throw DomainGraphViolation.workItemCurrencyInvalid
        }
        if let lineItem = workItem.invoiceLineItem {
            guard lineItem.sourceWorkItem === workItem else {
                throw DomainGraphViolation.invoiceLineItemWorkItemInverseMismatch
            }
        }
    }

    private static func validate(_ businessProfile: BusinessProfile) throws {
        guard TextNormalization.required(businessProfile.name) == businessProfile.name else {
            throw DomainGraphViolation.businessProfileNameNotNormalized
        }
        guard
            isNormalized(businessProfile.phone),
            isNormalized(businessProfile.email),
            isNormalized(businessProfile.address),
            isNormalized(businessProfile.defaultInvoiceNote)
        else {
            throw DomainGraphViolation.businessProfileOptionalTextNotNormalized
        }
        guard businessProfile.nextInvoiceNumber > 0 else {
            throw DomainGraphViolation.businessProfileSequenceInvalid
        }
    }

    private static func validate(
        _ invoice: Invoice,
        visits: [InvoiceVisit]
    ) throws {
        guard let client = invoice.client else {
            throw DomainGraphViolation.invoiceMissingClient
        }
        guard client.invoices.contains(where: { $0 === invoice }) else {
            throw DomainGraphViolation.invoiceClientInverseMismatch
        }
        guard
            TextNormalization.required(invoice.clientNameSnapshot) == invoice.clientNameSnapshot,
            TextNormalization.required(invoice.businessNameSnapshot) == invoice.businessNameSnapshot,
            isNormalized(invoice.clientPhoneSnapshot),
            isNormalized(invoice.clientEmailSnapshot),
            isNormalized(invoice.businessPhoneSnapshot),
            isNormalized(invoice.businessEmailSnapshot),
            isNormalized(invoice.businessAddressSnapshot),
            isNormalized(invoice.note)
        else {
            throw DomainGraphViolation.invoiceSnapshotNotNormalized
        }
        guard invoice.currencyCode == "USD" else {
            throw DomainGraphViolation.invoiceCurrencyInvalid
        }
        do {
            _ = try InvoiceDomainRules.validatedStatus(
                rawValue: invoice.statusRawValue,
                paidAt: invoice.paidAt
            )
        } catch {
            throw DomainGraphViolation.invoiceStatusInvalid
        }
        guard !visits.isEmpty else {
            throw DomainGraphViolation.invoiceHasNoVisit
        }
        guard
            visits.count == invoice.invoiceVisits.count,
            visits.allSatisfy({ $0.invoice === invoice }),
            invoice.invoiceVisits.allSatisfy({ $0.invoice === invoice })
        else {
            throw DomainGraphViolation.invoiceVisitInvoiceInverseMismatch
        }

        var sourceVisitIDs = Set<PersistentIdentifier>()
        var amounts = [Int64]()
        for invoiceVisit in visits {
            guard let sourceVisit = invoiceVisit.sourceVisit else {
                throw DomainGraphViolation.invoiceVisitMissingSourceVisit
            }
            guard sourceVisitIDs.insert(sourceVisit.persistentModelID).inserted else {
                throw DomainGraphViolation.duplicateInvoiceVisitSource
            }
            amounts.append(contentsOf: invoiceVisit.lineItems.map(\.amountMinorUnits))
        }
        do {
            _ = try InvoiceDomainRules.checkedTotal(amounts)
        } catch {
            throw DomainGraphViolation.invoiceTotalOverflow
        }
    }

    private static func validate(
        _ invoiceVisit: InvoiceVisit,
        lineItems: [InvoiceLineItem]
    ) throws {
        guard let invoice = invoiceVisit.invoice else {
            throw DomainGraphViolation.invoiceVisitMissingInvoice
        }
        guard let sourceVisit = invoiceVisit.sourceVisit else {
            throw DomainGraphViolation.invoiceVisitMissingSourceVisit
        }
        guard invoice.invoiceVisits.contains(where: { $0 === invoiceVisit }) else {
            throw DomainGraphViolation.invoiceVisitInvoiceInverseMismatch
        }
        guard sourceVisit.invoiceVisits.contains(where: { $0 === invoiceVisit }) else {
            throw DomainGraphViolation.invoiceVisitSourceInverseMismatch
        }
        guard
            TextNormalization.required(invoiceVisit.serviceLocationNameSnapshot)
                == invoiceVisit.serviceLocationNameSnapshot,
            isNormalized(invoiceVisit.serviceLocationAddressSnapshot)
        else {
            throw DomainGraphViolation.invoiceVisitSnapshotNotNormalized
        }
        guard !lineItems.isEmpty else {
            throw DomainGraphViolation.invoiceVisitHasNoLineItem
        }
        guard
            lineItems.count == invoiceVisit.lineItems.count,
            lineItems.allSatisfy({ $0.invoiceVisit === invoiceVisit }),
            invoiceVisit.lineItems.allSatisfy({ $0.invoiceVisit === invoiceVisit })
        else {
            throw DomainGraphViolation.invoiceLineItemVisitInverseMismatch
        }
    }

    private static func validate(_ lineItem: InvoiceLineItem) throws {
        guard let invoiceVisit = lineItem.invoiceVisit else {
            throw DomainGraphViolation.invoiceLineItemMissingInvoiceVisit
        }
        guard let sourceWorkItem = lineItem.sourceWorkItem else {
            throw DomainGraphViolation.invoiceLineItemMissingSourceWorkItem
        }
        guard invoiceVisit.lineItems.contains(where: { $0 === lineItem }) else {
            throw DomainGraphViolation.invoiceLineItemVisitInverseMismatch
        }
        guard sourceWorkItem.invoiceLineItem === lineItem else {
            throw DomainGraphViolation.invoiceLineItemWorkItemInverseMismatch
        }
        guard
            let sourceVisitHorse = sourceWorkItem.visitHorse,
            let sourceVisit = sourceVisitHorse.visit,
            invoiceVisit.sourceVisit === sourceVisit
        else {
            throw DomainGraphViolation.invoiceLineItemSourceVisitMismatch
        }
        guard
            TextNormalization.required(lineItem.horseNameSnapshot) == lineItem.horseNameSnapshot,
            TextNormalization.required(lineItem.serviceNameSnapshot) == lineItem.serviceNameSnapshot
        else {
            throw DomainGraphViolation.invoiceLineItemSnapshotNotNormalized
        }
        guard lineItem.amountMinorUnits >= 0 else {
            throw DomainGraphViolation.invoiceLineItemAmountNegative
        }
        guard lineItem.currencyCode == "USD" else {
            throw DomainGraphViolation.invoiceLineItemCurrencyInvalid
        }
        guard
            let invoiceClient = invoiceVisit.invoice?.client,
            sourceVisitHorse.horse?.client === invoiceClient
        else {
            throw DomainGraphViolation.invoiceLineItemClientMismatch
        }
    }

    private static func validate(_ photograph: Photograph) throws {
        guard let visitHorse = photograph.visitHorse else {
            throw DomainGraphViolation.photographMissingVisitHorse
        }
        guard visitHorse.photographs.contains(where: { $0 === photograph }) else {
            throw DomainGraphViolation.photographInverseMismatch
        }
        guard
            photograph.pixelWidth > 0,
            photograph.pixelHeight > 0,
            max(photograph.pixelWidth, photograph.pixelHeight) <= 2_560
        else {
            throw DomainGraphViolation.invalidPhotographDimensions
        }
        guard photograph.byteCount > 0 else {
            throw DomainGraphViolation.invalidPhotographByteCount
        }
    }

    private static func validate(
        _ appointment: Appointment,
        memberships: [AppointmentHorse],
        visits: [Visit]
    ) throws {
        guard let barn = appointment.barn else {
            throw DomainGraphViolation.appointmentMissingBarn
        }
        guard !memberships.isEmpty else {
            throw DomainGraphViolation.appointmentHasNoValidHorse
        }
        guard visits.count <= 1 else {
            throw DomainGraphViolation.appointmentVisitMismatch
        }

        let visit = appointment.visit
        if let visit {
            guard visit.appointment === appointment, visits.first === visit else {
                throw DomainGraphViolation.appointmentVisitMismatch
            }
        } else if !visits.isEmpty {
            throw DomainGraphViolation.appointmentVisitMismatch
        }

        var horseIDs = Set<PersistentIdentifier>()
        for membership in memberships {
            guard let horse = membership.horse else {
                throw DomainGraphViolation.appointmentHorseMissingHorse
            }
            if visit?.completedAt == nil, horse.currentBarn !== barn {
                throw DomainGraphViolation.horseOutsideAppointmentBarn
            }
            guard horseIDs.insert(horse.persistentModelID).inserted else {
                throw DomainGraphViolation.duplicateHorseMembership
            }
        }
    }

    private static func validate(
        _ visit: Visit,
        memberships: [VisitHorse],
        appointmentMemberships: inout [PersistentIdentifier: [AppointmentHorse]]
    ) throws {
        guard let appointment = visit.appointment else {
            throw DomainGraphViolation.visitMissingAppointment
        }
        guard let barn = visit.barn else {
            throw DomainGraphViolation.visitMissingBarn
        }
        guard appointment.visit === visit, appointment.barn === barn else {
            throw DomainGraphViolation.appointmentVisitMismatch
        }
        guard TextNormalization.required(visit.serviceLocationNameSnapshot) != nil else {
            throw DomainGraphViolation.visitLocationNameMissing
        }
        guard !memberships.isEmpty else {
            throw DomainGraphViolation.visitHasNoHorse
        }
        guard visit.invoiceVisits.allSatisfy({ $0.sourceVisit === visit }) else {
            throw DomainGraphViolation.invoiceVisitSourceInverseMismatch
        }

        let appointmentHorseIDs = try Set(
            appointmentMemberships[appointment.persistentModelID, default: []].map { membership in
                guard let horse = membership.horse else {
                    throw DomainGraphViolation.appointmentHorseMissingHorse
                }
                return horse.persistentModelID
            }
        )

        var visitHorseIDs = Set<PersistentIdentifier>()
        var hasPendingHorse = false
        var hasServicedHorse = false
        var subtotals = [MoneyAvailability]()
        for membership in memberships {
            guard let horse = membership.horse else {
                throw DomainGraphViolation.visitHorseMissingHorse
            }
            guard visitHorseIDs.insert(horse.persistentModelID).inserted else {
                throw DomainGraphViolation.duplicateVisitHorseMembership
            }

            guard let outcome = VisitOutcome(rawValue: membership.outcomeRawValue) else {
                throw DomainGraphViolation.visitMembershipMismatch
            }
            if TextNormalization.optional(membership.workNotes ?? "") != nil,
               outcome != .serviced {
                throw DomainGraphViolation.workNotesRequireServicedOutcome
            }
            let workItems = membership.workItems
            if outcome == .notServiced, !workItems.isEmpty {
                throw DomainGraphViolation.notServicedVisitHorseHasWorkItems
            }
            var serviceIDs = Set<PersistentIdentifier>()
            for workItem in workItems {
                guard let service = workItem.service else {
                    throw DomainGraphViolation.workItemMissingService
                }
                guard serviceIDs.insert(service.persistentModelID).inserted else {
                    throw DomainGraphViolation.duplicateWorkItemService
                }
            }
            do {
                subtotals.append(
                    try CheckedMoneyTotal.projectedSubtotal(
                        workItems.map(\.amountMinorUnits),
                        unavailableWhenEmpty: false
                    )
                )
            } catch {
                throw DomainGraphViolation.workItemTotalOverflow
            }
            hasPendingHorse = hasPendingHorse || outcome == .pending
            hasServicedHorse = hasServicedHorse || outcome == .serviced

            if visit.completedAt != nil,
               outcome == .serviced,
               workItems.isEmpty {
                throw DomainGraphViolation.completedServicedVisitHorseHasNoWorkItems
            }
        }

        guard visitHorseIDs == appointmentHorseIDs else {
            throw DomainGraphViolation.visitMembershipMismatch
        }

        if let completedAt = visit.completedAt {
            guard completedAt >= visit.startedAt else {
                throw DomainGraphViolation.completionPredatesStart
            }
            guard !hasPendingHorse else {
                throw DomainGraphViolation.completedVisitHasPendingHorse
            }
            guard hasServicedHorse else {
                throw DomainGraphViolation.completedVisitHasNoServicedHorse
            }
        }

        do {
            _ = try CheckedMoneyTotal.projectedTotal(subtotals)
        } catch {
            throw DomainGraphViolation.workItemTotalOverflow
        }
    }

    private static func isNormalized(_ value: String?) -> Bool {
        guard let value else { return true }
        return TextNormalization.optional(value) == value
    }
}
