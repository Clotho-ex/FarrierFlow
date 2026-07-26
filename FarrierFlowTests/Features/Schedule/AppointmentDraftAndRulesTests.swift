import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Appointment draft and rules")
@MainActor
struct AppointmentDraftAndRulesTests {
    @Test
    func durationIsOptionalPositiveAndNeverDerivedFromHorseCount() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let barn = Barn(name: "North Field")
        context.insert(barn)
        try context.save()

        var draft = AppointmentDraft(
            barnID: barn.persistentModelID,
            selectedHorseIDs: []
        )
        #expect(!draft.isValid)
        #expect(draft.expectedDurationMinutes == nil)

        draft.expectedDurationText = "0"
        #expect(!draft.isValid)
        draft.expectedDurationText = "abc"
        #expect(!draft.isValid)
        draft.expectedDurationText = "45"
        #expect(draft.expectedDurationMinutes == 45)
    }

    @Test
    func validationRejectsEmptyDuplicateAndIneligibleSelections() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let first = Client(name: "First")
        let second = Client(name: "Second")
        context.insert(first)
        context.insert(second)
        try context.save()
        let firstID = first.persistentModelID
        let secondID = second.persistentModelID

        #expect(AppointmentRules.validate(
            selectedHorseIDs: [],
            eligibleHorseIDs: [firstID]
        ) == .noHorses)
        #expect(AppointmentRules.validate(
            selectedHorseIDs: [firstID, firstID],
            eligibleHorseIDs: [firstID]
        ) == .duplicateHorse)
        #expect(AppointmentRules.validate(
            selectedHorseIDs: [secondID],
            eligibleHorseIDs: [firstID]
        ) == .ineligibleHorse)
        #expect(AppointmentRules.validate(
            selectedHorseIDs: [firstID, secondID],
            eligibleHorseIDs: [firstID, secondID]
        ) == .valid)
    }
}
