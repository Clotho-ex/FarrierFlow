import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Invoice creation model", .serialized)
@MainActor
struct InvoiceCreationModelTests {
    @Test
    func loadDefaultsDatesAndNoteThenSelectAllKeepsOnlyVisitSelectionState() throws {
        let graph = try makeCreationGraph(hasBusinessProfile: true)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let model = InvoiceCreationModel(clientID: graph.clientID)

        model.load(in: graph.context, now: now, calendar: calendar)

        let loadedDraft = try #require(model.draft)
        #expect(model.loadState == .loaded)
        #expect(model.clientName == "Alex Carter")
        #expect(model.hasValidBusinessProfile)
        #expect(loadedDraft.invoiceDate == now)
        let expectedDueDate = try InvoiceDateRules.defaultDueDate(
            for: now,
            calendar: calendar
        )
        #expect(loadedDraft.dueDate == expectedDueDate)
        #expect(loadedDraft.note == "Thank you.")
        #expect(loadedDraft.selectedVisitIDs.isEmpty)
        #expect(model.selectionSummary == nil)
        #expect(!model.canGenerate)

        model.selectAll()

        #expect(model.draft?.selectedVisitIDs == Set(model.visitChoices.map(\.id)))
        #expect(
            model.selectionSummary == InvoiceSelectionSummary(
                visitCount: 2,
                recordedServiceCount: 2,
                totalMinorUnits: try InvoiceDomainRules.checkedTotal(
                    model.visitChoices.map(\.subtotalMinorUnits)
                )
            )
        )
        #expect(model.canGenerate)
        model.toggleVisit(graph.firstVisitID)
        #expect(model.draft?.selectedVisitIDs == [graph.secondVisitID])
        #expect(model.selectionSummary?.visitCount == 1)
        #expect(model.selectionSummary?.recordedServiceCount == 1)
    }

    @Test
    func reloadPreservesAnEditedNoteAndClearedDueDateWhileIntersectingSelection() throws {
        let graph = try makeCreationGraph(hasBusinessProfile: true)
        let model = InvoiceCreationModel(clientID: graph.clientID)
        model.load(in: graph.context, now: Date(timeIntervalSinceReferenceDate: 1_000))
        var draft = try #require(model.draft)
        draft.note = "A custom note"
        draft.dueDate = nil
        draft.selectedVisitIDs = [graph.firstVisitID, graph.secondVisitID]
        model.draft = draft

        let firstVisit = try #require(
            graph.context.model(for: graph.firstVisitID) as? Visit
        )
        let billedWorkItem = try #require(firstVisit.visitHorses.first?.workItems.first)
        let profile = try #require(
            graph.context.fetch(FetchDescriptor<BusinessProfile>()).first
        )
        let client = try #require(graph.context.model(for: graph.clientID) as? Client)
        let invoice = ModelFixtures.makeInvoice(
            number: 1,
            client: client,
            businessProfile: profile,
            in: graph.context
        )
        let invoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: invoice,
            sourceVisit: firstVisit,
            in: graph.context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: invoiceVisit,
            sourceWorkItem: billedWorkItem,
            in: graph.context
        )
        profile.nextInvoiceNumber = 2
        try DomainGraphValidator.save(graph.context)

        model.load(in: graph.context, now: Date(timeIntervalSinceReferenceDate: 2_000))

        #expect(model.draft?.note == "A custom note")
        #expect(model.draft?.dueDate == nil)
        #expect(model.draft?.selectedVisitIDs == [graph.secondVisitID])
    }

    @Test
    func missingBusinessProfileKeepsEligibilityVisibleButBlocksGeneration() throws {
        let graph = try makeCreationGraph(hasBusinessProfile: false)
        let model = InvoiceCreationModel(clientID: graph.clientID)

        model.load(in: graph.context, now: Date(timeIntervalSinceReferenceDate: 1_000))
        model.selectAll()

        #expect(model.loadState == .loaded)
        #expect(!model.hasValidBusinessProfile)
        #expect(!model.visitChoices.isEmpty)
        #expect(!model.canGenerate)
    }

    @Test
    func reloadPrefillsDefaultNoteAfterMissingProfileIsCreated() throws {
        let graph = try makeCreationGraph(hasBusinessProfile: false)
        let model = InvoiceCreationModel(clientID: graph.clientID)
        model.load(in: graph.context, now: Date(timeIntervalSinceReferenceDate: 1_000))
        #expect(model.draft?.note == "")

        _ = ModelFixtures.makeBusinessProfile(
            defaultInvoiceNote: "Thank you.",
            in: graph.context
        )
        try DomainGraphValidator.save(graph.context)

        model.load(in: graph.context, now: Date(timeIntervalSinceReferenceDate: 2_000))

        #expect(model.hasValidBusinessProfile)
        #expect(model.draft?.note == "Thank you.")
    }

    private func makeCreationGraph(
        hasBusinessProfile: Bool
    ) throws -> InvoiceCreationGraph {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex Carter")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)
        let firstHorse = Horse(name: "Milo", client: client, currentBarn: barn)
        let secondHorse = Horse(name: "Atlas", client: client, currentBarn: barn)
        context.insert(firstHorse)
        context.insert(secondHorse)
        client.horses.append(contentsOf: [firstHorse, secondHorse])
        barn.horses.append(contentsOf: [firstHorse, secondHorse])
        let service = ModelFixtures.makeService(in: context)
        let firstVisit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 150),
            appointment: ModelFixtures.makeAppointment(
                barn: barn,
                horses: [firstHorse],
                in: context
            ),
            in: context
        )
        let secondVisit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 200),
            completedAt: Date(timeIntervalSinceReferenceDate: 250),
            appointment: ModelFixtures.makeAppointment(
                barn: barn,
                horses: [secondHorse],
                in: context
            ),
            in: context
        )
        for visit in [firstVisit, secondVisit] {
            let visitHorse = try #require(visit.visitHorses.first)
            visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
            _ = ModelFixtures.makeWorkItem(service: service, visitHorse: visitHorse, in: context)
        }
        if hasBusinessProfile {
            _ = ModelFixtures.makeBusinessProfile(in: context)
        }
        try DomainGraphValidator.save(context)

        return InvoiceCreationGraph(
            container: container,
            context: context,
            clientID: client.persistentModelID,
            firstVisitID: firstVisit.persistentModelID,
            secondVisitID: secondVisit.persistentModelID
        )
    }
}

private struct InvoiceCreationGraph {
    let container: ModelContainer
    let context: ModelContext
    let clientID: PersistentIdentifier
    let firstVisitID: PersistentIdentifier
    let secondVisitID: PersistentIdentifier
}
