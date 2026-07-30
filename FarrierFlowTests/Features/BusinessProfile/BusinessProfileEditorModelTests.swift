import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Business Profile editor model", .serialized)
@MainActor
struct BusinessProfileEditorModelTests {
    @Test
    func loadsAnEmptyDraftThenCreatesTheSoleProfileAtSequenceOne() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let model = BusinessProfileEditorModel()

        model.load(in: context)

        #expect(model.loadState == .loaded)
        #expect(model.draft == BusinessProfileDraft())
        #expect(!model.canSave)

        model.draft = BusinessProfileDraft(
            name: "  Carter Farrier Service ",
            phone: " 555-0100 ",
            email: " alex@example.com ",
            address: " 1 Main Street ",
            defaultInvoiceNote: " Thank you. "
        )

        #expect(model.canSave)
        #expect(model.save(in: context))

        let profiles = try context.fetch(FetchDescriptor<BusinessProfile>())
        let profile = try #require(profiles.first)
        #expect(profiles.count == 1)
        #expect(profile.name == "Carter Farrier Service")
        #expect(profile.phone == "555-0100")
        #expect(profile.email == "alex@example.com")
        #expect(profile.address == "1 Main Street")
        #expect(profile.defaultInvoiceNote == "Thank you.")
        #expect(profile.nextInvoiceNumber == 1)
    }

    @Test
    func editsTheExistingProfileAndPreservesItsInvoiceSequence() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let profile = ModelFixtures.makeBusinessProfile(
            name: "Carter Farrier Service",
            nextInvoiceNumber: 42,
            in: context
        )
        try DomainGraphValidator.save(context)
        let model = BusinessProfileEditorModel()

        model.load(in: context)

        #expect(model.draft.name == "Carter Farrier Service")
        #expect(model.draft.phone == "555-0100")
        model.draft.name = "Carter and Son Farriers"
        model.draft.phone = ""
        model.draft.email = "office@example.com"
        model.draft.address = ""
        model.draft.defaultInvoiceNote = ""

        #expect(model.save(in: context))
        #expect(profile.name == "Carter and Son Farriers")
        #expect(profile.phone == nil)
        #expect(profile.email == "office@example.com")
        #expect(profile.address == nil)
        #expect(profile.defaultInvoiceNote == nil)
        #expect(profile.nextInvoiceNumber == 42)
        #expect(try context.fetchCount(FetchDescriptor<BusinessProfile>()) == 1)
    }

    @Test
    func failsClosedWhenMoreThanOneProfileExists() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        _ = ModelFixtures.makeBusinessProfile(name: "First", in: context)
        _ = ModelFixtures.makeBusinessProfile(name: "Second", in: context)
        let model = BusinessProfileEditorModel()

        model.load(in: context)

        #expect(model.loadState == .failed)
        #expect(!model.canSave)
        #expect(!model.save(in: context))
        #expect(try context.fetchCount(FetchDescriptor<BusinessProfile>()) == 2)
    }

    @Test
    func failedSaveRollsBackPersistenceAndKeepsTheRecoverableDraft() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let profile = ModelFixtures.makeBusinessProfile(
            name: "Carter Farrier Service",
            nextInvoiceNumber: 12,
            in: context
        )
        let client = ModelFixtures.makeClient()
        let barn = ModelFixtures.makeBarn()
        let horse = ModelFixtures.makeHorse(client: client, barn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        try DomainGraphValidator.save(context)
        let model = BusinessProfileEditorModel()
        model.load(in: context)
        model.draft.name = "Updated Farrier Name"
        horse.client = nil

        #expect(!model.save(in: context))
        #expect(model.draft.name == "Updated Farrier Name")
        #expect(model.alert != nil)

        let persistedProfile = try #require(
            context.fetch(FetchDescriptor<BusinessProfile>()).first
        )
        #expect(persistedProfile.name == "Carter Farrier Service")
        #expect(persistedProfile.nextInvoiceNumber == 12)
        #expect(profile.name == "Carter Farrier Service")
    }

    @Test
    func profileEditsDoNotRewriteExistingInvoiceSnapshots() throws {
        let graph = try makeInvoiceGraph()
        let model = BusinessProfileEditorModel()
        model.load(in: graph.context)
        model.draft = BusinessProfileDraft(
            name: "New Business Name",
            phone: "555-9999",
            email: "new@example.com",
            address: "99 New Street",
            defaultInvoiceNote: "A new default note."
        )

        #expect(model.save(in: graph.context))

        #expect(graph.profile.name == "New Business Name")
        #expect(graph.invoice.businessNameSnapshot == "Original Farrier")
        #expect(graph.invoice.businessPhoneSnapshot == "555-0100")
        #expect(graph.invoice.businessEmailSnapshot == "original@example.com")
        #expect(graph.invoice.businessAddressSnapshot == "1 Main Street")
        #expect(graph.invoice.note == "Original invoice note.")
    }

    private func makeInvoiceGraph() throws -> (
        container: ModelContainer,
        context: ModelContext,
        profile: BusinessProfile,
        invoice: Invoice
    ) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(
            name: "Alex Carter",
            phone: "555-0110",
            email: "alex@example.com"
        )
        let barn = ModelFixtures.makeBarn()
        let horse = ModelFixtures.makeHorse(client: client, barn: barn)
        context.insert(client)
        context.insert(barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [horse],
            in: context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 100),
            completedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: appointment,
            in: context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let service = ModelFixtures.makeService(in: context)
        let workItem = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: context
        )
        let profile = ModelFixtures.makeBusinessProfile(
            name: "Original Farrier",
            phone: "555-0100",
            email: "original@example.com",
            address: "1 Main Street",
            defaultInvoiceNote: "Original default note.",
            nextInvoiceNumber: 2,
            in: context
        )
        let invoice = ModelFixtures.makeInvoice(
            number: 1,
            client: client,
            businessProfile: profile,
            note: "Original invoice note.",
            in: context
        )
        let invoiceVisit = ModelFixtures.makeInvoiceVisit(
            invoice: invoice,
            sourceVisit: visit,
            in: context
        )
        _ = try ModelFixtures.makeInvoiceLineItem(
            invoiceVisit: invoiceVisit,
            sourceWorkItem: workItem,
            in: context
        )
        try DomainGraphValidator.save(context)
        return (container, context, profile, invoice)
    }
}
