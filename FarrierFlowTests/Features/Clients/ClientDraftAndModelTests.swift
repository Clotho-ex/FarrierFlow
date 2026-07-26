import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Client drafts and models")
@MainActor
struct ClientDraftAndModelTests {
    @Test
    func draftRequiresTrimmedNameOnly() {
        #expect(!ClientDraft(name: "  ").isValid)
        #expect(ClientDraft(name: " Alex ", phone: "not formatted").isValid)
    }

    @Test
    func createNormalizesFieldsAndEditPreservesIdentity() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let editor = ClientEditorModel()
        editor.draft = ClientDraft(
            name: "  Alex Carter ",
            phone: " ",
            email: "alex@example.com",
            notes: "\n"
        )

        let id = try #require(editor.save(in: context))
        let client = try #require(context.model(for: id) as? Client)
        #expect(client.name == "Alex Carter")
        #expect(client.phone == nil)
        #expect(client.email == "alex@example.com")
        #expect(client.notes == nil)

        let edit = ClientEditorModel(client: client)
        edit.draft.name = "Alex B. Carter"
        #expect(edit.save(in: context) == id)
        #expect(client.name == "Alex B. Carter")
    }

    @Test
    func listLoadsAlphabetically() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        context.insert(Client(name: "Zoe"))
        context.insert(Client(name: "Alex"))
        try context.save()

        let model = ClientListModel()
        model.load(in: context)
        #expect(model.clients.map(\.name) == ["Alex", "Zoe"])
    }
}
