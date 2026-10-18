import Foundation
import SwiftData

nonisolated enum InvoiceGenerationError: Error, Equatable {
    case clientUnavailable
    case businessProfileUnavailable
    case businessProfileInvalid
    case noVisitsSelected
    case visitUnavailable
    case visitNoLongerEligible
    case invoiceNumberOverflow
    case notDesignatedInvoicingPhone
    case invoicingAuthorityUnavailable
}

@MainActor
enum InvoiceGenerationUseCase {
    static func generate(
        _ draft: InvoiceCreationDraft,
        in context: ModelContext,
        deviceIDProvider: @Sendable () throws -> UUID = { try SyncDeviceIdentity.loadOrCreate() }
    ) throws -> PersistentIdentifier {
        do {
            try DomainGraphValidator.validateAll(in: context)
            try requireInvoicingAuthority(in: context, deviceIDProvider: deviceIDProvider)
            guard !draft.selectedVisitIDs.isEmpty else {
                throw InvoiceGenerationError.noVisitsSelected
            }
            guard let client = try context.existingModel(Client.self, for: draft.clientID) else {
                throw InvoiceGenerationError.clientUnavailable
            }
            let businessProfile = try soleBusinessProfile(in: context)
            guard businessProfile.nextInvoiceNumber > 0 else {
                throw InvoiceGenerationError.businessProfileInvalid
            }
            let (nextInvoiceNumber, didOverflow) = businessProfile.nextInvoiceNumber
                .addingReportingOverflow(1)
            guard !didOverflow else {
                throw InvoiceGenerationError.invoiceNumberOverflow
            }

            let selectedVisits: [(visit: Visit, workItems: [WorkItem])] = try draft.selectedVisitIDs.map { visitID in
                guard let visit = try context.existingModel(Visit.self, for: visitID) else {
                    throw InvoiceGenerationError.visitUnavailable
                }
                let workItems = try InvoiceEligibilityRules.eligibleWorkItems(
                    for: client,
                    in: visit
                )
                guard !workItems.isEmpty else {
                    throw InvoiceGenerationError.visitNoLongerEligible
                }
                return (visit: visit, workItems: workItems)
            }
            let orderedSelections = InvoiceEligibilityRules.orderedVisits(
                selectedVisits.map(\.visit)
            ).compactMap { visit in
                selectedVisits.first { $0.visit === visit }
            }

            let invoice = Invoice(
                number: businessProfile.nextInvoiceNumber,
                invoiceDate: draft.invoiceDate,
                dueDate: draft.dueDate,
                note: TextNormalization.optional(draft.note),
                clientNameSnapshot: client.name,
                clientPhoneSnapshot: client.phone,
                clientEmailSnapshot: client.email,
                businessNameSnapshot: businessProfile.name,
                businessPhoneSnapshot: businessProfile.phone,
                businessEmailSnapshot: businessProfile.email,
                businessAddressSnapshot: businessProfile.address,
                currencyCode: businessProfile.currencyCode,
                client: client
            )
            context.insert(invoice)
            client.invoices.append(invoice)

            var amounts = [Int64]()
            for (visit, workItems) in orderedSelections {
                let invoiceVisit = InvoiceVisit(
                    visitDateSnapshot: visit.startedAt,
                    serviceLocationNameSnapshot: visit.serviceLocationNameSnapshot,
                    serviceLocationAddressSnapshot: visit.serviceLocationAddressSnapshot,
                    invoice: invoice,
                    sourceVisit: visit
                )
                context.insert(invoiceVisit)
                invoice.invoiceVisits.append(invoiceVisit)
                visit.invoiceVisits.append(invoiceVisit)

                for workItem in workItems {
                    guard let horse = workItem.visitHorse?.horse else {
                        throw InvoiceEligibilityError.invalidSourceRelationship
                    }
                    let lineItem = InvoiceLineItem(
                        horseNameSnapshot: horse.name,
                        serviceNameSnapshot: workItem.serviceNameSnapshot,
                        amountMinorUnits: workItem.amountMinorUnits,
                        currencyCode: workItem.currencyCode,
                        invoiceVisit: invoiceVisit,
                        sourceWorkItem: workItem
                    )
                    context.insert(lineItem)
                    invoiceVisit.lineItems.append(lineItem)
                    workItem.invoiceLineItem = lineItem
                    amounts.append(lineItem.amountMinorUnits)
                }
            }

            _ = try InvoiceDomainRules.checkedTotal(amounts)
            businessProfile.nextInvoiceNumber = nextInvoiceNumber
            try DomainGraphValidator.save(context)
            return invoice.persistentModelID
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func requireInvoicingAuthority(
        in context: ModelContext, deviceIDProvider: @Sendable () throws -> UUID
    ) throws {
        let journal: SyncJournal
        do {
            // Sync metadata may have changed while an invoice editor remained
            // open. Do not trust its cached SwiftData identity map for authority.
            journal = try SyncJournalStore.read(in: ModelContext(context.container))
        } catch SyncJournalStoreError.unbound {
            return
        } catch SyncJournalStoreError.cloudAccountDeleted {
            // Cloud deletion retains a usable local-only business. It must not
            // retain remote invoicing authority or reopen the deleted dataset.
            return
        }
        guard journal.invoicingGeneration > 0, let designated = journal.invoicingDeviceID else {
            throw InvoiceGenerationError.invoicingAuthorityUnavailable
        }
        let device: UUID
        do { device = try deviceIDProvider() }
        catch { throw InvoiceGenerationError.invoicingAuthorityUnavailable }
        guard device == designated else { throw InvoiceGenerationError.notDesignatedInvoicingPhone }
    }

    private static func soleBusinessProfile(
        in context: ModelContext
    ) throws -> BusinessProfile {
        var descriptor = FetchDescriptor<BusinessProfile>()
        descriptor.fetchLimit = 2
        let profiles = try context.fetch(descriptor)
        guard profiles.count == 1, let profile = profiles.first else {
            throw InvoiceGenerationError.businessProfileUnavailable
        }
        return profile
    }
}
