import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Invoice eligibility rules", .serialized)
@MainActor
struct InvoiceEligibilityRulesTests {
    @Test
    func choicesIncludeOnlyCompletedUninvoicedWorkOwnedByTheReceivingClient() throws {
        let graph = try makeEligibilityGraph()

        let alexChoices = try InvoiceEligibilityRules.choices(
            for: graph.alexID,
            in: graph.context
        )
        let blairChoices = try InvoiceEligibilityRules.choices(
            for: graph.blairID,
            in: graph.context
        )

        #expect(alexChoices.map(\.id) == [graph.earlyVisitID, graph.mixedVisitID])
        #expect(alexChoices.map(\.eligibleWorkItemCount) == [1, 2])
        #expect(alexChoices.map(\.subtotalMinorUnits) == [4_000, 20_000])
        #expect(blairChoices.map(\.id) == [graph.mixedVisitID])
        #expect(blairChoices.map(\.eligibleWorkItemCount) == [1])
        #expect(blairChoices.map(\.subtotalMinorUnits) == [7_000])
        #expect(!alexChoices.contains(where: { $0.id == graph.inProgressVisitID }))
    }

    @Test
    func linkedWorkItemsAreExcludedWithoutBlockingAnotherClientsVisitPortion() throws {
        let graph = try makeEligibilityGraph()
        let profile = ModelFixtures.makeBusinessProfile(
            nextInvoiceNumber: 2,
            in: graph.context
        )
        let alex = try #require(
            graph.context.model(for: graph.alexID) as? Client
        )
        let mixedVisit = try #require(
            graph.context.model(for: graph.mixedVisitID) as? Visit
        )
        let invoice = ModelFixtures.makeInvoice(
            number: 1,
            client: alex,
            businessProfile: profile,
            in: graph.context
        )
        let invoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: invoice,
            sourceVisit: mixedVisit,
            in: graph.context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: invoiceVisit,
            sourceWorkItem: graph.alexMixedWorkItemIDs[0].model(in: graph.context),
            in: graph.context
        )
        try DomainGraphValidator.save(graph.context)

        let alexChoice = try #require(
            InvoiceEligibilityRules.choices(for: graph.alexID, in: graph.context)
                .first(where: { $0.id == graph.mixedVisitID })
        )
        let blairChoice = try #require(
            InvoiceEligibilityRules.choices(for: graph.blairID, in: graph.context)
                .first(where: { $0.id == graph.mixedVisitID })
        )

        #expect(alexChoice.eligibleWorkItemCount == 1)
        #expect(alexChoice.subtotalMinorUnits == 8_000)
        #expect(blairChoice.eligibleWorkItemCount == 1)
        #expect(blairChoice.subtotalMinorUnits == 7_000)
    }

    private func makeEligibilityGraph() throws -> InvoiceEligibilityGraph {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let alex = Client(name: "Alex Carter")
        let blair = Client(name: "Blair Stone")
        let barn = Barn(name: "North Field")
        context.insert(alex)
        context.insert(blair)
        context.insert(barn)

        let milo = Horse(name: "Milo", client: alex, currentBarn: barn)
        let atlas = Horse(name: "Atlas", client: alex, currentBarn: barn)
        let scout = Horse(name: "Scout", client: blair, currentBarn: barn)
        context.insert(milo)
        context.insert(atlas)
        context.insert(scout)
        alex.horses.append(contentsOf: [milo, atlas])
        blair.horses.append(scout)
        barn.horses.append(contentsOf: [milo, atlas, scout])

        let earlyVisit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 150),
            appointment: ModelFixtures.makeAppointment(
                barn: barn,
                horses: [atlas],
                in: context
            ),
            in: context
        )
        let mixedVisit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 200),
            completedAt: Date(timeIntervalSinceReferenceDate: 250),
            appointment: ModelFixtures.makeAppointment(
                barn: barn,
                horses: [milo, scout],
                in: context
            ),
            in: context
        )
        let inProgressVisit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 300),
            appointment: ModelFixtures.makeAppointment(
                barn: barn,
                horses: [atlas],
                in: context
            ),
            in: context
        )

        let trim = ModelFixtures.makeService(
            name: "Trim",
            defaultAmountMinorUnits: 4_000,
            in: context
        )
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
        let earlyHorse = try #require(earlyVisit.visitHorses.first)
        let mixedMilo = try #require(
            mixedVisit.visitHorses.first(where: { $0.horse === milo })
        )
        let mixedScout = try #require(
            mixedVisit.visitHorses.first(where: { $0.horse === scout })
        )
        let inProgressHorse = try #require(inProgressVisit.visitHorses.first)
        for horse in [earlyHorse, mixedMilo, mixedScout] {
            horse.outcomeRawValue = VisitOutcome.serviced.rawValue
        }
        _ = ModelFixtures.makeWorkItem(service: trim, visitHorse: earlyHorse, in: context)
        let firstAlexMixed = ModelFixtures.makeWorkItem(
            service: frontShoes,
            visitHorse: mixedMilo,
            in: context
        )
        let secondAlexMixed = ModelFixtures.makeWorkItem(
            service: pads,
            visitHorse: mixedMilo,
            in: context
        )
        _ = ModelFixtures.makeWorkItem(service: hindShoes, visitHorse: mixedScout, in: context)
        _ = ModelFixtures.makeWorkItem(service: trim, visitHorse: inProgressHorse, in: context)
        try DomainGraphValidator.save(context)

        return InvoiceEligibilityGraph(
            container: container,
            context: context,
            alexID: alex.persistentModelID,
            blairID: blair.persistentModelID,
            earlyVisitID: earlyVisit.persistentModelID,
            mixedVisitID: mixedVisit.persistentModelID,
            inProgressVisitID: inProgressVisit.persistentModelID,
            alexMixedWorkItemIDs: [
                firstAlexMixed.persistentModelID,
                secondAlexMixed.persistentModelID,
            ]
        )
    }
}

private struct InvoiceEligibilityGraph {
    let container: ModelContainer
    let context: ModelContext
    let alexID: PersistentIdentifier
    let blairID: PersistentIdentifier
    let earlyVisitID: PersistentIdentifier
    let mixedVisitID: PersistentIdentifier
    let inProgressVisitID: PersistentIdentifier
    let alexMixedWorkItemIDs: [PersistentIdentifier]
}

private extension PersistentIdentifier {
    func model(in context: ModelContext) throws -> WorkItem {
        try #require(context.model(for: self) as? WorkItem)
    }
}
