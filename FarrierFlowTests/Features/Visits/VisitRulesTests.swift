import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Visit draft rules", .serialized)
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
    func completionRequiresARecordedServiceForEachServicedHorse() throws {
        let draft = try makeDraft(outcomes: [(.serviced, "")])

        #expect(VisitRules.completionViolation(in: draft) == nil)

        var missingWorkItem = draft
        missingWorkItem.horses[0].workItems = []
        #expect(
            VisitRules.completionViolation(in: missingWorkItem)
                == .servicedHorseRequiresWorkItem
        )
    }

    @Test
    func progressRejectsWorkItemsForNotServicedHorse() throws {
        var draft = try makeDraft(outcomes: [(.serviced, "")])
        draft.horses[0].outcome = .notServiced

        #expect(VisitRules.progressViolation(in: draft) == .notServicedHorseHasWorkItems)
    }

    @Test
    func progressAllowsPendingHorseWithDraftWorkItems() throws {
        var draft = try makeDraft(outcomes: [(.serviced, "")])
        draft.horses[0].outcome = .pending

        #expect(VisitRules.progressViolation(in: draft) == nil)
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
        let draft = try makeDraft(outcomes: [(.serviced, "")])
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

    @Test
    func applyingRecordedWorkCopiesEverySnapshotToUntouchedTargetsWithFreshIdentity() throws {
        var original = try makeDraft(outcomes: [
            (.serviced, "Source notes stay private"),
            (.serviced, ""),
            (.pending, ""),
        ])
        let secondService = try #require(original.horses[1].workItems.first)
        original.horses[0].workItems.append(
            WorkItemDraft(
                serviceID: secondService.serviceID,
                serviceNameSnapshot: secondService.serviceNameSnapshot,
                amountMinorUnits: 9_125,
                currencyCode: secondService.currencyCode,
                serviceIsArchived: secondService.serviceIsArchived
            )
        )
        original.horses[1].outcome = .pending
        original.horses[1].workItems = []
        let source = original.horses[0]
        let targetIDs = [original.horses[1].id, original.horses[2].id]

        let result = VisitRules.applyingRecordedWork(
            from: source.id,
            to: targetIDs,
            in: original
        )
        let updated = try #require(try result.get())

        #expect(updated.horses[0] == source)
        for targetID in targetIDs {
            let target = try #require(updated.horses.first(where: { $0.id == targetID }))
            #expect(target.outcome == .serviced)
            #expect(target.workNotes.isEmpty)
            #expect(target.workItems.count == source.workItems.count)
            #expect(target.workItems.map(\.serviceID) == source.workItems.map(\.serviceID))
            #expect(
                target.workItems.map(\.serviceNameSnapshot)
                    == source.workItems.map(\.serviceNameSnapshot)
            )
            #expect(
                target.workItems.map(\.amountMinorUnits)
                    == source.workItems.map(\.amountMinorUnits)
            )
            #expect(target.workItems.allSatisfy { $0.persistentID == nil })
            #expect(Set(target.workItems.map(\.id)).isDisjoint(with: source.workItems.map(\.id)))
        }
        #expect(
            Set(updated.horses[1].workItems.map(\.id))
                .isDisjoint(with: updated.horses[2].workItems.map(\.id))
        )
        #expect(VisitRules.progressViolation(in: updated) == nil)
        #expect(VisitRules.completionViolation(in: updated) == nil)
        #expect(original.horses[1].outcome == .pending)
        #expect(original.horses[1].workItems.isEmpty)
    }

    @Test
    func applyingRecordedWorkRequiresANonemptyUniqueTargetSelectionOutsideTheSource() throws {
        let draft = try makeDraft(outcomes: [(.serviced, ""), (.pending, "")])
        let sourceID = draft.horses[0].id
        let targetID = draft.horses[1].id

        #expect(
            VisitRules.applyingRecordedWork(from: sourceID, to: [], in: draft)
                == .failure(.targetSelectionRequired)
        )
        #expect(
            VisitRules.applyingRecordedWork(
                from: sourceID,
                to: [targetID, targetID],
                in: draft
            ) == .failure(.duplicateTarget)
        )
        #expect(
            VisitRules.applyingRecordedWork(from: sourceID, to: [sourceID], in: draft)
                == .failure(.sourceSelectedAsTarget)
        )
    }

    @Test
    func applyingRecordedWorkRejectsAnInvalidSource() throws {
        var draft = try makeDraft(outcomes: [(.serviced, ""), (.pending, "")])
        let sourceID = draft.horses[0].id
        let targetID = draft.horses[1].id

        draft.horses[0].outcome = .pending
        #expect(
            VisitRules.applyingRecordedWork(from: sourceID, to: [targetID], in: draft)
                == .failure(.sourceMustBeServiced)
        )

        draft.horses[0].outcome = .serviced
        draft.horses[0].workItems = []
        #expect(
            VisitRules.applyingRecordedWork(from: sourceID, to: [targetID], in: draft)
                == .failure(.sourceRequiresRecordedWork)
        )

        let duplicate = try #require(
            makeDraft(outcomes: [(.serviced, "")]).horses[0].workItems.first
        )
        draft.horses[0].workItems = [duplicate, duplicate]
        #expect(
            VisitRules.applyingRecordedWork(from: sourceID, to: [targetID], in: draft)
                == .failure(.invalidSourceWork(.duplicateService))
        )

        draft.horses[0].workItems = [
            WorkItemDraft(
                serviceID: duplicate.serviceID,
                serviceNameSnapshot: duplicate.serviceNameSnapshot,
                amountMinorUnits: duplicate.amountMinorUnits,
                serviceIsArchived: true
            ),
        ]
        #expect(
            VisitRules.applyingRecordedWork(from: sourceID, to: [targetID], in: draft)
                == .failure(.sourceContainsArchivedService)
        )
    }

    @Test(arguments: [VisitOutcome.serviced, .notServiced])
    func applyingRecordedWorkRejectsEveryExplicitTargetOutcome(
        _ targetOutcome: VisitOutcome
    ) throws {
        let draft = try makeDraft(outcomes: [(.serviced, ""), (targetOutcome, "")])

        #expect(
            VisitRules.applyingRecordedWork(
                from: draft.horses[0].id,
                to: [draft.horses[1].id],
                in: draft
            ) == .failure(.targetMustBePending)
        )
    }

    @Test
    func applyingRecordedWorkRejectsPendingTargetsWithNotesOrRecordedWork() throws {
        var draft = try makeDraft(outcomes: [(.serviced, ""), (.pending, "")])
        let sourceID = draft.horses[0].id
        let targetID = draft.horses[1].id

        draft.horses[1].workNotes = "Existing target notes"
        #expect(
            VisitRules.applyingRecordedWork(from: sourceID, to: [targetID], in: draft)
                == .failure(.targetHasWorkNotes)
        )

        draft.horses[1].workNotes = ""
        draft.horses[1].workItems = draft.horses[0].workItems
        #expect(
            VisitRules.applyingRecordedWork(from: sourceID, to: [targetID], in: draft)
                == .failure(.targetHasRecordedWork)
        )
    }

    private func makeDraft(
        outcomes: [(VisitOutcome, String)]
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
            horses: zip(zip(visitHorses, horses), outcomes).enumerated().map { index, entry in
                let (pair, item) = entry
                let (visitHorse, horse) = pair
                return VisitHorseDraft(
                    id: visitHorse.persistentModelID,
                    horseID: horse.persistentModelID,
                    horseName: horse.name,
                    outcome: item.0,
                    workNotes: item.1,
                    workItems: item.0 == .serviced
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
