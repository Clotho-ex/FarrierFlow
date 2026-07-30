import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Invoice generation use case", .serialized)
@MainActor
struct InvoiceGenerationUseCaseTests {
    @Test
    func generatesEveryEligibleClientWorkItemWithExactImmutableSnapshots() throws {
        let graph = try makeGenerationGraph()
        let invoiceID = try InvoiceGenerationUseCase.generate(
            InvoiceCreationDraft(
                clientID: graph.alexID,
                selectedVisitIDs: [graph.mixedVisitID],
                invoiceDate: Date(timeIntervalSinceReferenceDate: 500),
                dueDate: Date(timeIntervalSinceReferenceDate: 514),
                note: "  Thank you for your business.  "
            ),
            in: ModelContext(graph.container)
        )
        let verificationContext = ModelContext(graph.container)
        let invoice = try #require(
            verificationContext.model(for: invoiceID) as? Invoice
        )
        let invoiceVisit = try #require(invoice.invoiceVisits.first)
        let lines = InvoiceDomainRules.orderedLineItems(
            invoiceVisit.lineItems,
            locale: Locale(identifier: "en_US")
        )

        #expect(invoice.number == 1)
        #expect(try InvoiceDomainRules.formattedNumber(invoice.number) == "0001")
        #expect(invoice.invoiceDate == Date(timeIntervalSinceReferenceDate: 500))
        #expect(invoice.dueDate == Date(timeIntervalSinceReferenceDate: 514))
        #expect(invoice.note == "Thank you for your business.")
        #expect(invoice.clientNameSnapshot == "Alex Carter")
        #expect(invoice.clientPhoneSnapshot == "555-0100")
        #expect(invoice.clientEmailSnapshot == "alex@example.com")
        #expect(invoice.businessNameSnapshot == "Carter Farrier Service")
        #expect(invoice.businessPhoneSnapshot == "555-0101")
        #expect(invoice.businessEmailSnapshot == "office@example.com")
        #expect(invoice.businessAddressSnapshot == "1 Main Street")
        #expect(invoice.currencyCode == "USD")
        #expect(invoiceVisit.visitDateSnapshot == Date(timeIntervalSinceReferenceDate: 200))
        #expect(invoiceVisit.serviceLocationNameSnapshot == "North Field")
        #expect(invoiceVisit.serviceLocationAddressSnapshot == "25 Stable Lane")
        #expect(lines.map(\.horseNameSnapshot) == ["Milo", "Milo"])
        #expect(lines.map(\.serviceNameSnapshot) == ["Front Shoes", "Pads"])
        #expect(lines.map(\.amountMinorUnits) == [12_000, 8_000])
        #expect(lines.map(\.sourceWorkItem?.persistentModelID) == graph.alexWorkItemIDs)
        #expect(try InvoiceDomainRules.checkedTotal(lines.map(\.amountMinorUnits)) == 20_000)
        #expect(lines.allSatisfy { $0.currencyCode == "USD" })
        #expect(lines.allSatisfy { $0.sourceWorkItem?.invoiceLineItem === $0 })
        #expect(
            try #require(
                verificationContext.model(for: graph.blairWorkItemID) as? WorkItem
            ).invoiceLineItem == nil
        )
        #expect(
            try InvoiceEligibilityRules.choices(
                for: graph.blairID,
                in: verificationContext
            ).map(\.id) == [graph.mixedVisitID]
        )
        #expect(try #require(
            verificationContext.fetch(FetchDescriptor<BusinessProfile>()).first
        ).nextInvoiceNumber == 2)
    }

    @Test
    func mixedClientVisitGeneratesSeparateInvoicesWithSequentialNumbers() throws {
        let graph = try makeGenerationGraph()
        let alexInvoiceID = try InvoiceGenerationUseCase.generate(
            draft(for: graph.alexID, visitID: graph.mixedVisitID),
            in: ModelContext(graph.container)
        )
        let blairInvoiceID = try InvoiceGenerationUseCase.generate(
            draft(for: graph.blairID, visitID: graph.mixedVisitID),
            in: ModelContext(graph.container)
        )
        let context = ModelContext(graph.container)
        let alexInvoice = try #require(context.model(for: alexInvoiceID) as? Invoice)
        let blairInvoice = try #require(context.model(for: blairInvoiceID) as? Invoice)
        let profile = try #require(context.fetch(FetchDescriptor<BusinessProfile>()).first)

        #expect(alexInvoice.number == 1)
        #expect(blairInvoice.number == 2)
        #expect(profile.nextInvoiceNumber == 3)
        #expect(alexInvoice.invoiceVisits.count == 1)
        #expect(blairInvoice.invoiceVisits.count == 1)
        #expect(alexInvoice.invoiceVisits.first?.sourceVisit === blairInvoice.invoiceVisits.first?.sourceVisit)
        #expect(alexInvoice.invoiceVisits.first?.lineItems.count == 2)
        #expect(blairInvoice.invoiceVisits.first?.lineItems.count == 1)
    }

    @Test
    func repeatedOrOverflowGenerationLeavesNoNewSnapshotsLinksOrSequenceAdvance() throws {
        let graph = try makeGenerationGraph()
        _ = try InvoiceGenerationUseCase.generate(
            draft(for: graph.alexID, visitID: graph.mixedVisitID),
            in: ModelContext(graph.container)
        )

        #expect(throws: InvoiceGenerationError.visitNoLongerEligible) {
            _ = try InvoiceGenerationUseCase.generate(
                draft(for: graph.alexID, visitID: graph.mixedVisitID),
                in: ModelContext(graph.container)
            )
        }
        let afterRepeat = ModelContext(graph.container)
        #expect(try afterRepeat.fetchCount(FetchDescriptor<Invoice>()) == 1)
        #expect(try #require(
            afterRepeat.fetch(FetchDescriptor<BusinessProfile>()).first
        ).nextInvoiceNumber == 2)

        let overflow = try makeGenerationGraph(nextInvoiceNumber: .max)
        #expect(throws: InvoiceGenerationError.invoiceNumberOverflow) {
            _ = try InvoiceGenerationUseCase.generate(
                draft(for: overflow.alexID, visitID: overflow.mixedVisitID),
                in: ModelContext(overflow.container)
            )
        }
        let overflowContext = ModelContext(overflow.container)
        #expect(try overflowContext.fetch(FetchDescriptor<Invoice>()).isEmpty)
        #expect(try overflowContext.fetch(FetchDescriptor<InvoiceVisit>()).isEmpty)
        #expect(try overflowContext.fetch(FetchDescriptor<InvoiceLineItem>()).isEmpty)
        #expect(try #require(
            overflowContext.fetch(FetchDescriptor<BusinessProfile>()).first
        ).nextInvoiceNumber == .max)
        #expect(try #require(
            overflowContext.model(for: overflow.alexWorkItemIDs[0]) as? WorkItem
        ).invoiceLineItem == nil)
    }

    @Test
    func generatedInvoiceAndSourceWorkItemLinksSurviveStoreReopening() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Generated-Invoice-Reopen-"
        )
        let storeURL = directory.appending(path: "FarrierFlow.store")

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let graph = try makeGenerationGraph(in: container.mainContext, container: container)
            _ = try InvoiceGenerationUseCase.generate(
                draft(for: graph.alexID, visitID: graph.mixedVisitID),
                in: ModelContext(container)
            )
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            let invoice = try #require(context.fetch(FetchDescriptor<Invoice>()).first)
            let invoiceVisit = try #require(invoice.invoiceVisits.first)
            let profile = try #require(context.fetch(FetchDescriptor<BusinessProfile>()).first)

            #expect(invoice.number == 1)
            #expect(profile.nextInvoiceNumber == 2)
            #expect(invoice.invoiceVisits.count == 1)
            #expect(invoiceVisit.lineItems.count == 2)
            #expect(invoiceVisit.lineItems.allSatisfy {
                $0.sourceWorkItem?.invoiceLineItem === $0
            })
            try DomainGraphValidator.validateAll(in: context)
        }
    }

    private func draft(
        for clientID: PersistentIdentifier,
        visitID: PersistentIdentifier
    ) -> InvoiceCreationDraft {
        InvoiceCreationDraft(
            clientID: clientID,
            selectedVisitIDs: [visitID],
            invoiceDate: Date(timeIntervalSinceReferenceDate: 500),
            dueDate: Date(timeIntervalSinceReferenceDate: 514),
            note: "Thank you."
        )
    }

    private func makeGenerationGraph(
        nextInvoiceNumber: Int64 = 1
    ) throws -> InvoiceGenerationGraph {
        let container = try ModelContainerFactory.inMemoryTest()
        return try makeGenerationGraph(
            in: container.mainContext,
            container: container,
            nextInvoiceNumber: nextInvoiceNumber
        )
    }

    private func makeGenerationGraph(
        in context: ModelContext,
        container: ModelContainer,
        nextInvoiceNumber: Int64 = 1
    ) throws -> InvoiceGenerationGraph {
        let alex = Client(
            name: "Alex Carter",
            phone: "555-0100",
            email: "alex@example.com"
        )
        let blair = Client(name: "Blair Stone")
        let barn = Barn(name: "North Field", address: "25 Stable Lane")
        context.insert(alex)
        context.insert(blair)
        context.insert(barn)
        let milo = Horse(name: "Milo", client: alex, currentBarn: barn)
        let scout = Horse(name: "Scout", client: blair, currentBarn: barn)
        context.insert(milo)
        context.insert(scout)
        alex.horses.append(milo)
        blair.horses.append(scout)
        barn.horses.append(contentsOf: [milo, scout])
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 200),
            completedAt: Date(timeIntervalSinceReferenceDate: 250),
            appointment: ModelFixtures.makeAppointment(
                barn: barn,
                horses: [milo, scout],
                in: context
            ),
            in: context
        )
        let miloVisitHorse = try #require(
            visit.visitHorses.first(where: { $0.horse === milo })
        )
        let scoutVisitHorse = try #require(
            visit.visitHorses.first(where: { $0.horse === scout })
        )
        miloVisitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        scoutVisitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let frontShoes = ModelFixtures.makeService(
            name: "Front Shoes",
            defaultAmountMinorUnits: 12_000,
            in: context
        )
        let pads = ModelFixtures.makeService(
            name: "Pads",
            defaultAmountMinorUnits: 8_000,
            in: context
        )
        let hindShoes = ModelFixtures.makeService(
            name: "Hind Shoes",
            defaultAmountMinorUnits: 7_000,
            in: context
        )
        let frontWorkItem = ModelFixtures.makeWorkItem(
            service: frontShoes,
            visitHorse: miloVisitHorse,
            in: context
        )
        let padsWorkItem = ModelFixtures.makeWorkItem(
            service: pads,
            visitHorse: miloVisitHorse,
            in: context
        )
        let blairWorkItem = ModelFixtures.makeWorkItem(
            service: hindShoes,
            visitHorse: scoutVisitHorse,
            in: context
        )
        _ = ModelFixtures.makeBusinessProfile(
            name: "Carter Farrier Service",
            phone: "555-0101",
            email: "office@example.com",
            address: "1 Main Street",
            defaultInvoiceNote: "Thank you.",
            nextInvoiceNumber: nextInvoiceNumber,
            in: context
        )
        try DomainGraphValidator.save(context)

        return InvoiceGenerationGraph(
            container: container,
            alexID: alex.persistentModelID,
            blairID: blair.persistentModelID,
            mixedVisitID: visit.persistentModelID,
            alexWorkItemIDs: [
                frontWorkItem.persistentModelID,
                padsWorkItem.persistentModelID,
            ],
            blairWorkItemID: blairWorkItem.persistentModelID
        )
    }
}

private struct InvoiceGenerationGraph {
    let container: ModelContainer
    let alexID: PersistentIdentifier
    let blairID: PersistentIdentifier
    let mixedVisitID: PersistentIdentifier
    let alexWorkItemIDs: [PersistentIdentifier]
    let blairWorkItemID: PersistentIdentifier
}
