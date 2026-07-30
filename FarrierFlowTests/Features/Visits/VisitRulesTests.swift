import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Visit draft rules")
@MainActor
struct VisitRulesTests {
    @Test
    func outcomeDecodesKnownPersistedRawValue() throws {
        let decoded = try JSONDecoder().decode(VisitOutcome.self, from: Data("\"notServiced\"".utf8))

        #expect(decoded == .notServiced)
        #expect(VisitRules.outcome(for: "serviced") == .success(.serviced))
    }

    @Test
    func unknownPersistedRawValueIsRejectedAtTheLoadBoundary() {
        #expect(VisitRules.outcome(for: "rescheduled") == .failure(.unknownOutcome))
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(VisitOutcome.self, from: Data("\"rescheduled\"".utf8))
        }
    }

    @Test
    func whitespaceOnlyWorkNotesAreTreatedAsEmpty() throws {
        let draft = try makeDraft(outcomes: [(.pending, " \n\t ")])

        #expect(VisitRules.progressViolation(in: draft) == nil)
        #expect(!VisitRules.requiresWorkNotesClearConfirmation(
            from: draft.horses[0],
            to: .notServiced
        ))
    }

    @Test
    func progressAllowsPendingAndMixedResolvedOutcomes() throws {
        let pending = try makeDraft(outcomes: [(.pending, "")])
        let mixedResolved = try makeDraft(outcomes: [
            (.serviced, "Trimmed front hooves"),
            (.notServiced, ""),
        ])

        #expect(VisitRules.progressViolation(in: pending) == nil)
        #expect(VisitRules.progressViolation(in: mixedResolved) == nil)
    }

    @Test
    func progressRejectsDuplicateHorseIdentity() throws {
        var draft = try makeDraft(outcomes: [(.serviced, "")])
        draft.horses.append(draft.horses[0])

        #expect(VisitRules.progressViolation(in: draft) == .duplicateHorse)
    }

    @Test(arguments: [VisitOutcome.pending, .notServiced])
    func progressRejectsWorkNotesForNonServicedOutcome(_ outcome: VisitOutcome) throws {
        let draft = try makeDraft(outcomes: [(outcome, "Could not complete")])

        #expect(VisitRules.progressViolation(in: draft) == .workNotesRequireServicedOutcome)
    }

    @Test
    func completionRejectsAllPendingOutcomes() throws {
        let draft = try makeDraft(outcomes: [(.pending, ""), (.pending, "")])

        #expect(VisitRules.completionViolation(in: draft) == .pendingOutcomePreventsCompletion)
    }

    @Test
    func completionRejectsAnyRemainingPendingOutcome() throws {
        let draft = try makeDraft(outcomes: [(.serviced, ""), (.pending, "")])

        #expect(VisitRules.completionViolation(in: draft) == .pendingOutcomePreventsCompletion)
    }

    @Test
    func completionRequiresAtLeastOneServicedHorse() throws {
        let draft = try makeDraft(outcomes: [(.notServiced, ""), (.notServiced, "")])

        #expect(VisitRules.completionViolation(in: draft) == .completionRequiresServicedHorse)
    }

    @Test
    func completionAllowsResolvedDraftWithAServicedHorse() throws {
        let draft = try makeDraft(outcomes: [(.serviced, "Trimmed front hooves"), (.notServiced, "")])

        #expect(VisitRules.completionViolation(in: draft) == nil)
    }

    @Test
    func policyOneCompletionRequiresARecordedServiceForEachServicedHorse() throws {
        let draft = try makeDraft(
            outcomes: [(.serviced, "")],
            policy: 1
        )

        #expect(VisitRules.completionViolation(in: draft) == nil)

        var missingWorkItem = draft
        missingWorkItem.horses[0].workItems = []
        #expect(
            VisitRules.completionViolation(in: missingWorkItem)
                == .policyOneServicedHorseRequiresWorkItem
        )
    }

    @Test
    func progressRejectsWorkItemsForNotServicedHorseUnderEitherPolicy() throws {
        var draft = try makeDraft(
            outcomes: [(.serviced, "")],
            policy: 1
        )
        draft.horses[0].outcome = .notServiced

        #expect(VisitRules.progressViolation(in: draft) == .notServicedHorseHasWorkItems)
    }

    @Test
    func progressAllowsPendingHorseWithDraftWorkItems() throws {
        var draft = try makeDraft(
            outcomes: [(.serviced, "")],
            policy: 1
        )
        draft.horses[0].outcome = .pending

        #expect(VisitRules.progressViolation(in: draft) == nil)
    }

    @Test
    func progressRejectsUnknownWorkItemPolicy() throws {
        let draft = try makeDraft(outcomes: [(.pending, "")], policy: 2)

        #expect(VisitRules.progressViolation(in: draft) == .invalidWorkItemPolicyVersion)
    }

    @Test
    func correctionRejectsPendingOutcomes() throws {
        let draft = try makeDraft(outcomes: [(.serviced, ""), (.pending, "")])

        #expect(VisitRules.correctionViolation(in: draft) == .pendingOutcomePreventsCompletion)
    }

    @Test
    func correctionRetainsAtLeastOneServicedHorse() throws {
        let draft = try makeDraft(outcomes: [(.notServiced, "")])

        #expect(VisitRules.correctionViolation(in: draft) == .completionRequiresServicedHorse)
    }

    @Test
    func correctionPickerDoesNotOfferPendingOutcome() {
        #expect(
            VisitRules.selectableOutcomes(for: .inProgress)
                == [.pending, .serviced, .notServiced]
        )
        #expect(
            VisitRules.selectableOutcomes(for: .correction)
                == [.serviced, .notServiced]
        )
    }

    @Test
    func leavingServicedOutcomeWithNotesRequiresConfirmationBeforeClearingThem() throws {
        let draft = try makeDraft(outcomes: [(.serviced, "Trimmed front hooves")])

        #expect(VisitRules.requiresWorkNotesClearConfirmation(
            from: draft.horses[0],
            to: .notServiced
        ))
        #expect(!VisitRules.requiresWorkNotesClearConfirmation(
            from: draft.horses[0],
            to: .serviced
        ))
    }

    @Test
    func leavingPendingOutcomeWithDraftWorkItemsRequiresConfirmationBeforeClearingThem() throws {
        let draft = try makeDraft(outcomes: [(.serviced, "")], policy: 1)
        var pendingHorse = draft.horses[0]
        pendingHorse.outcome = .pending

        #expect(VisitRules.requiresWorkNotesClearConfirmation(
            from: pendingHorse,
            to: .notServiced
        ))
    }

    @Test
    func dirtyStateIsExactInequalityFromLastSavedDraft() throws {
        let saved = try makeDraft(outcomes: [(.serviced, "Trimmed front hooves")])
        var edited = saved

        #expect(edited == saved)
        edited.horses[0].workNotes = "Trimmed front and rear hooves"
        #expect(edited != saved)
    }

    private func makeDraft(
        outcomes: [(VisitOutcome, String)],
        policy: Int = 0
    ) throws -> VisitDraft {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex Carter")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)

        let horses = outcomes.enumerated().map { index, _ in
            let horse = Horse(
                name: "Horse \(index + 1)",
                client: client,
                currentBarn: barn
            )
            context.insert(horse)
            client.horses.append(horse)
            barn.horses.append(horse)
            return horse
        }
        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: horses,
            in: context
        )
        let visit = Visit(
            startedAt: .now,
            serviceLocationNameSnapshot: barn.name,
            workItemPolicyVersion: policy,
            appointment: appointment,
            barn: barn
        )
        context.insert(visit)
        appointment.visit = visit
        barn.visits.append(visit)

        let visitHorses = zip(horses, outcomes).map { horse, item in
            let visitHorse = VisitHorse(
                outcomeRawValue: item.0.rawValue,
                workNotes: item.1,
                visit: visit,
                horse: horse
            )
            context.insert(visitHorse)
            visit.visitHorses.append(visitHorse)
            horse.visitHorses.append(visitHorse)
            return visitHorse
        }
        let serviceIDs = horses.enumerated().map { index, _ in
            let service = Service(
                name: "Service \(index + 1)",
                defaultAmountMinorUnits: 7_500
            )
            context.insert(service)
            return service.persistentModelID
        }
        try context.save()

        return VisitDraft(
            visitID: visit.persistentModelID,
            workItemPolicyVersion: policy,
            horses: zip(zip(visitHorses, horses), outcomes).enumerated().map { index, entry in
                let (pair, item) = entry
                let (visitHorse, horse) = pair
                return VisitHorseDraft(
                    id: visitHorse.persistentModelID,
                    horseID: horse.persistentModelID,
                    horseName: horse.name,
                    outcome: item.0,
                    workNotes: item.1,
                    workItems: policy == 1 && item.0 == .serviced
                        ? [
                            WorkItemDraft(
                                serviceID: serviceIDs[index],
                                serviceNameSnapshot: "Service \(index + 1)",
                                amountMinorUnits: 7_500
                            ),
                        ]
                        : []
                )
            }
        )
    }
}
