import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Business Profile editor model", .serialized)
@MainActor
struct BusinessProfileEditorModelTests {
    @Test
    func setupSavesServicesWithBusinessCurrencyAndDoesNotDuplicateOnResave() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let model = BusinessProfileEditorModel()
        model.load(in: context, locale: Locale(identifier: "de_DE"))
        model.draft.name = "Field Farrier"
        model.draft.currencyCode = "EUR"
        model.addSetupService()
        model.setupServices[0].service.name = "Trim"
        model.setupServices[0].service.priceInput = "45,50"
        model.addSetupService()
        model.setupServices[1].service.name = "Full Set"
        model.setupServices[1].service.priceInput = "90,25"
        #expect(model.canSave)
        #expect(model.save(in: context))
        let check = ModelContext(container)
        let services = try check.fetch(FetchDescriptor<Service>())
        #expect(services.count == 2)
        #expect(services.first { $0.name == "Trim" }?.defaultAmountMinorUnits == 4550)
        #expect(services.first { $0.name == "Full Set" }?.defaultAmountMinorUnits == 9025)
        #expect(services.allSatisfy { $0.currencyCode == "EUR" })
        #expect(try check.fetch(FetchDescriptor<BusinessProfile>()).first?.currencyCode == "EUR")
        #expect(model.isCurrencyLocked)
        #expect(model.setupServices.isEmpty)
        #expect(model.save(in: context))
        #expect(try context.fetchCount(FetchDescriptor<Service>()) == 2)
    }

    @Test
    func invalidSetupServiceLeavesEntireBusinessUnsavedAndCanBeRemoved() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let model = BusinessProfileEditorModel()
        model.load(in: context)
        model.draft.name = "Field Farrier"
        model.addSetupService()
        model.setupServices[0].service.name = "Trim"
        model.setupServices[0].service.priceInput = "45"
        model.addSetupService()
        model.setupServices[1].service.name = "Full Set"
        model.setupServices[1].service.priceInput = "not a price"
        #expect(!model.canSave)
        #expect(!model.save(in: context))
        #expect(try context.fetchCount(FetchDescriptor<BusinessProfile>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<Service>()) == 0)
        #expect(model.setupServices.count == 2)
        model.setupServices = []
        #expect(model.canSave)
        #expect(model.save(in: context))
    }

    @Test
    func loadsAnEmptyDraftThenCreatesTheSoleProfileAtSequenceOne() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let model = BusinessProfileEditorModel()

        model.load(in: context, locale: Locale(identifier: "en_GB"))

        #expect(model.loadState == .loaded)
        #expect(model.draft == BusinessProfileDraft(currencyCode: "GBP"))
        #expect(!model.isCurrencyLocked)
        #expect(!model.canSave)

        model.draft = BusinessProfileDraft(
            name: "  Carter Farrier Service ",
            phone: " 555-0100 ",
            email: " alex@example.com ",
            address: " 1 Main Street ",
            defaultInvoiceNote: " Thank you. ",
            defaultAppointmentDurationMinutes: 45,
            defaultInvoiceDueDays: 30,
            currencyCode: "GBP"
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
        #expect(profile.defaultAppointmentDurationMinutes == 45)
        #expect(profile.defaultInvoiceDueDays == 30)
        #expect(profile.nextInvoiceNumber == 1)
        #expect(profile.currencyCode == "GBP")
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
        model.draft.defaultAppointmentDurationMinutes = 60
        model.draft.defaultInvoiceDueDays = nil

        #expect(model.save(in: context))
        #expect(profile.name == "Carter and Son Farriers")
        #expect(profile.phone == nil)
        #expect(profile.email == "office@example.com")
        #expect(profile.address == nil)
        #expect(profile.defaultInvoiceNote == nil)
        #expect(profile.defaultAppointmentDurationMinutes == 60)
        #expect(profile.defaultInvoiceDueDays == nil)
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

    @Test
    func existingFinancialRecordsLockCurrencyChanges() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let profile = ModelFixtures.makeBusinessProfile(
            currencyCode: "USD",
            in: context
        )
        _ = ModelFixtures.makeService(currencyCode: "USD", in: context)
        try DomainGraphValidator.save(context)
        let model = BusinessProfileEditorModel()

        model.load(in: context, locale: Locale(identifier: "en_GB"))

        #expect(model.isCurrencyLocked)
        #expect(model.draft.currencyCode == "USD")
        model.draft.currencyCode = "EUR"
        #expect(!model.save(in: context))
        #expect(profile.currencyCode == "USD")
        #expect(model.alert != nil)
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
