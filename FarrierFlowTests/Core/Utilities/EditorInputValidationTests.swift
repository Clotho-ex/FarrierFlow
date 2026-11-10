import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Editor input persistence", .serialized)
@MainActor
struct EditorInputValidationTests {
    @Test(arguments: ["a@@example.com", "a@example", "a@example..com", String(repeating: "a", count: 101) + "@example.com"])
    func invalidClientEmailCannotBeSaved(_ address: String) throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let model = ClientEditorModel()
        model.draft = ClientDraft(name: "Alex", email: address)
        #expect(!model.canSave)
        #expect(model.save(in: container.mainContext) == nil)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Client>()) == 0)
        #expect(!container.mainContext.hasChanges)
    }

    @Test
    func newPhoneUsesTheChosenRegionAndSurvivesEditingOnAnotherPhone() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let model = ClientEditorModel(locale: Locale(identifier: "en_IE"))
        model.draft = ClientDraft(name: "Alex", phone: "0872278701", email: "alex+visits@example.com")
        model.formatPhone()
        #expect(model.draft.phone == "+353 87 227 8701")
        let id = try #require(model.save(in: container.mainContext))
        let client = try #require(try container.mainContext.existingModel(Client.self, for: id))
        #expect(client.phone == "+353872278701")
        let searchable = ClientListSnapshot(client: client)
        #expect(searchable.matchesSearch("0872278701"))
        #expect(searchable.matchesSearch("+353 87 227 8701"))
        let otherPhone = ClientEditorModel(client: client, locale: Locale(identifier: "en_US"))
        #expect(otherPhone.draft.phone == "+353 87 227 8701")
        otherPhone.draft.notes = "Call before arrival."
        #expect(otherPhone.save(in: container.mainContext) == id)
        #expect(client.phone == "+353872278701")
    }

    @Test
    func editingOtherFieldsPreservesAmbiguousSavedLocalPhone() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let client = Client(name: "Alex", phone: "07700 900123")
        container.mainContext.insert(client)
        try DomainGraphValidator.save(container.mainContext)
        let model = ClientEditorModel(client: client, locale: Locale(identifier: "en_US"))
        model.formatPhone()
        model.draft.name = "Alex Carter"
        #expect(model.save(in: container.mainContext) != nil)
        #expect(client.phone == "07700 900123")
    }

    @Test
    func clientsAndLocationsEnforceTheBoundariesBeforeInserting() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let client = ClientEditorModel()
        client.draft = ClientDraft(name: String(repeating: "a", count: 60), notes: String(repeating: "n", count: 500))
        #expect(client.canSave)
        client.draft.notes.append("n")
        #expect(!client.canSave)
        #expect(client.save(in: container.mainContext) == nil)
        let barn = BarnEditorModel()
        barn.draft = BarnDraft(name: "Field", address: String(repeating: "a", count: 201))
        #expect(!barn.canSave)
        #expect(barn.save(in: container.mainContext) == nil)
        #expect(!container.mainContext.hasChanges)
    }

    @Test
    func businessRejectsInvalidEmailAndSavesNormalizedPhone() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let model = BusinessProfileEditorModel()
        model.load(in: container.mainContext, locale: Locale(identifier: "en_GB"))
        model.draft.name = "Field Farrier"
        model.draft.phone = "07700900123"
        model.draft.email = "invalid@domain"
        #expect(!model.canSave)
        #expect(!model.save(in: container.mainContext))
        #expect(try container.mainContext.fetchCount(FetchDescriptor<BusinessProfile>()) == 0)
        model.draft.email = "alex@example.com"
        #expect(model.canSave)
        #expect(model.save(in: container.mainContext))
        let profile = try #require(container.mainContext.fetch(FetchDescriptor<BusinessProfile>()).first)
        #expect(profile.phone == "+447700900123")
        #expect(model.draft.phone == "+44 7700 900123")
    }

    @Test
    func newerInvalidContactCannotBeSilentlyMergedIntoAnOpenEditor() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let client = Client(name: "Alex", email: "alex@example.com")
        container.mainContext.insert(client)
        try DomainGraphValidator.save(container.mainContext)
        let model = ClientEditorModel(client: client)
        model.draft.notes = "Local notes"
        client.email = "invalid@domain"
        try DomainGraphValidator.save(container.mainContext)
        #expect(model.save(in: container.mainContext) == nil)
        #expect(model.alert != nil)
        #expect(client.notes == nil)
        #expect(client.email == "invalid@domain")
        #expect(!container.mainContext.hasChanges)
    }

    @Test
    func boundsApplyToServiceNamesAndAppointmentNotes() {
        #expect(throws: ServiceRulesError.inputTooLong) {
            try ServiceRules.validated(ServiceDraft(name: String(repeating: "s", count: 61), priceInput: "50"))
        }
        #expect(AppointmentDraft(notes: String(repeating: "n", count: 501)).saveRequirement == .notesTooLong)
    }
}
