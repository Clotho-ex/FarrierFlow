import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Service location drafts and models")
@MainActor
struct BarnDraftAndModelTests {
    @Test
    func draftRequiresOnlyAName() {
        #expect(!BarnDraft().isValid)
        #expect(BarnDraft(name: "Private Stable").isValid)
    }

    @Test
    func createWithoutAddressIsIndependentAndEditable() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let editor = BarnEditorModel()
        editor.draft.name = " North Field "

        let id = try #require(
            editor.save(in: context, coordinator: PersistenceMutationCoordinator())
        )
        let barn = try #require(context.model(for: id) as? Barn)
        #expect(barn.name == "North Field")
        #expect(barn.address == nil)
        #expect(try context.fetchCount(FetchDescriptor<Client>()) == 0)

        let edit = BarnEditorModel(barn: barn)
        edit.draft.address = "100 Sample Road"
        #expect(
            edit.save(in: context, coordinator: PersistenceMutationCoordinator()) == id
        )
        #expect(barn.address == "100 Sample Road")
    }
}
