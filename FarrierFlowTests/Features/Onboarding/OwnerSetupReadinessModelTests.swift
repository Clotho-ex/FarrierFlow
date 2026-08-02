import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Owner setup readiness")
@MainActor
struct OwnerSetupReadinessModelTests {
    @Test
    func derivesIdentityReadinessFromTheSavedBusinessProfile() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let model = OwnerSetupReadinessModel()

        model.load(in: context)
        #expect(model.loadState == .loaded)
        #expect(!model.hasValidIdentity)

        _ = ModelFixtures.makeBusinessProfile(name: "Carter Farrier", in: context)
        try DomainGraphValidator.save(context)
        model.load(in: context)
        #expect(model.hasValidIdentity)
    }

    @Test
    func invalidIdentityDoesNotBypassSetup() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        context.insert(BusinessProfile(name: " "))
        try context.save()
        let model = OwnerSetupReadinessModel()

        model.load(in: context)

        #expect(model.loadState == .loaded)
        #expect(!model.hasValidIdentity)
    }
}
