import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Visit editor")
@MainActor
struct VisitEditorModelTests {
    @Test
    func loadStateRetainsPreviouslyLoadedDraftAfterFailureAndRetry() throws {
        let graph = try makeVisitGraph()
        var loadCount = 0
        let model = VisitEditorModel(
            visitID: graph.visitID,
            in: graph.container,
            loading: { visitID, context in
                loadCount += 1
                if loadCount == 2 {
                    throw VisitEditorTestFailure.unavailable
                }
                return try VisitEditorModel.loadDraft(visitID: visitID, in: context)
            }
        )

        #expect(model.loadState == .loading)
        #expect(model.draft == nil)

        model.load()
        let loadedDraft = try #require(model.draft)
        #expect(model.loadState == .loaded)
        #expect(model.lastSavedDraft == loadedDraft)
        #expect(!model.isDirty)

        model.load()

        #expect(model.loadState == .failed)
        #expect(model.draft == loadedDraft)
        #expect(model.lastSavedDraft == loadedDraft)
        #expect(model.alert != nil)

        model.retry()

        #expect(model.loadState == .loaded)
        #expect(model.draft == loadedDraft)
        #expect(model.lastSavedDraft == loadedDraft)
        #expect(model.alert == nil)
    }

    @Test
    func saveProgressPersistsNormalizedDraftAndUpdatesDirtyBaseline() throws {
        let graph = try makeVisitGraph()
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()

        var draft = try #require(model.draft)
        let miloIndex = try horseIndex(named: "Milo", in: draft)
        draft.horses[miloIndex].outcome = .serviced
        draft.horses[miloIndex].workNotes = "  Front shoes  "
        model.draft = draft

        #expect(model.isDirty)
        #expect(model.canSaveProgress)
        #expect(model.saveProgress())
        #expect(!model.isDirty)
        #expect(model.draft == model.lastSavedDraft)

        let verificationContext = ModelContext(graph.container)
        let visit = try #require(
            verificationContext.model(for: graph.visitID) as? Visit
        )
        let servicedHorse = try #require(
            visit.visitHorses.first(where: { $0.horse?.name == "Milo" })
        )
        #expect(servicedHorse.outcomeRawValue == VisitOutcome.serviced.rawValue)
        #expect(servicedHorse.workNotes == "Front shoes")
        #expect(visit.completedAt == nil)
    }

    @Test
    func workItemEditsExcludeUsedAndArchivedServicesAndPersistAtomically() throws {
        let graph = try makeVisitGraph()
        let setupContext = ModelContext(graph.container)
        let trim = ModelFixtures.makeService(
            name: "Trim",
            defaultAmountMinorUnits: 8_000,
            in: setupContext
        )
        let pads = ModelFixtures.makeService(
            name: "Pads",
            defaultAmountMinorUnits: 3_500,
            in: setupContext
        )
        _ = ModelFixtures.makeService(
            name: "Archived Service",
            defaultAmountMinorUnits: 2_000,
            isArchived: true,
            in: setupContext
        )
        try DomainGraphValidator.save(setupContext)

        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()
        let milo = try #require(model.draft?.horses.first(where: { $0.horseName == "Milo" }))
        let defaultWorkItem = try #require(milo.workItems.first)

        let initialEligible = model.eligibleServices(for: milo.id)
        #expect(initialEligible.map(\.id).contains(trim.persistentModelID))
        #expect(initialEligible.map(\.id).contains(pads.persistentModelID))
        #expect(!initialEligible.map(\.id).contains(defaultWorkItem.serviceID))
        #expect(!initialEligible.contains(where: { $0.name == "Archived Service" }))

        #expect(model.addService(trim.persistentModelID, to: milo.id))
        #expect(!model.addService(trim.persistentModelID, to: milo.id))
        let addedWorkItem = try #require(
            model.draft?.horses.first(where: { $0.id == milo.id })?.workItems
                .first(where: { $0.serviceID == trim.persistentModelID })
        )
        #expect(model.replaceWorkItem(addedWorkItem.id, with: pads.persistentModelID, for: milo.id))
        #expect(model.updateWorkItem(
            defaultWorkItem.id,
            serviceID: defaultWorkItem.serviceID,
            priceInput: "$140.25",
            for: milo.id
        ))
        #expect(!model.updateWorkItem(
            defaultWorkItem.id,
            serviceID: defaultWorkItem.serviceID,
            priceInput: "12.345",
            for: milo.id
        ))
        #expect(model.saveProgress())

        let verificationContext = ModelContext(graph.container)
        let visit = try #require(verificationContext.model(for: graph.visitID) as? Visit)
        let visitHorse = try #require(visit.visitHorses.first(where: { $0.horse?.name == "Milo" }))
        #expect(visitHorse.workItems.count == 2)
        #expect(visitHorse.workItems.contains {
            $0.service?.persistentModelID == defaultWorkItem.serviceID
                && $0.amountMinorUnits == 14_025
        })
        #expect(visitHorse.workItems.contains {
            $0.service?.persistentModelID == pads.persistentModelID
                && $0.serviceNameSnapshot == "Pads"
                && $0.amountMinorUnits == 3_500
        })
        #expect(visitHorse.workItems.allSatisfy { workItem in
            workItem.service?.workItems.contains(where: { $0.persistentModelID == workItem.persistentModelID }) == true
        })

        let persistedDraft = try #require(model.draft)
        let workItemToRemove = try #require(
            persistedDraft.horses.first(where: { $0.id == milo.id })?.workItems
                .first(where: { $0.serviceID == pads.persistentModelID })
        )
        #expect(model.removeWorkItem(workItemToRemove.id, from: milo.id))
        #expect(model.saveProgress())

        let afterRemovalContext = ModelContext(graph.container)
        let afterRemovalVisit = try #require(afterRemovalContext.model(for: graph.visitID) as? Visit)
        let afterRemovalHorse = try #require(
            afterRemovalVisit.visitHorses.first(where: { $0.horse?.name == "Milo" })
        )
        #expect(afterRemovalHorse.workItems.count == 1)
        try DomainGraphValidator.validateAll(in: afterRemovalContext)
    }

    @Test
    func failedWorkItemSaveKeepsDraftAndRollsBackAllWorkItemMutations() throws {
        let graph = try makeVisitGraph()
        let setupContext = ModelContext(graph.container)
        let service = ModelFixtures.makeService(name: "Trim", in: setupContext)
        try DomainGraphValidator.save(setupContext)
        let model = VisitEditorModel(
            visitID: graph.visitID,
            in: graph.container,
            saving: { _, _ in throw VisitEditorTestFailure.unavailable }
        )
        model.load()
        let milo = try #require(model.draft?.horses.first(where: { $0.horseName == "Milo" }))

        #expect(model.addService(service.persistentModelID, to: milo.id))
        let editedDraft = try #require(model.draft)
        #expect(!model.saveProgress())
        #expect(model.draft == editedDraft)

        let verificationContext = ModelContext(graph.container)
        let visit = try #require(verificationContext.model(for: graph.visitID) as? Visit)
        let visitHorse = try #require(visit.visitHorses.first(where: { $0.horse?.name == "Milo" }))
        #expect(visitHorse.workItems.count == 1)
        #expect(!visitHorse.workItems.contains { $0.service?.persistentModelID == service.persistentModelID })
    }

    @Test
    func servicedNotesRequireConfirmationBeforeAnOutcomeChangeClearsThem() throws {
        let graph = try makeVisitGraph()
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()

        var draft = try #require(model.draft)
        let miloIndex = try horseIndex(named: "Milo", in: draft)
        let horseID = draft.horses[miloIndex].id
        draft.horses[miloIndex].outcome = .serviced
        draft.horses[miloIndex].workNotes = "Watch for tenderness"
        model.draft = draft

        #expect(model.requestOutcomeChange(for: horseID, to: .notServiced))
        #expect(model.pendingOutcomeChange != nil)
        #expect(model.draft?.horses.first(where: { $0.horseName == "Milo" })?.outcome == .serviced)
        #expect(model.draft?.horses.first(where: { $0.horseName == "Milo" })?.workNotes == "Watch for tenderness")

        model.confirmPendingOutcomeChange()

        #expect(model.pendingOutcomeChange == nil)
        #expect(model.draft?.horses.first(where: { $0.horseName == "Milo" })?.outcome == .notServiced)
        #expect(model.draft?.horses.first(where: { $0.horseName == "Milo" })?.workNotes.isEmpty == true)
        #expect(model.draft?.horses.first(where: { $0.horseName == "Milo" })?.workItems.isEmpty == true)
        #expect(model.isDirty)
    }

    @Test
    func failedProgressSavePreservesDraftAndCannotLeakIntoLaterSaveOrReopen() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Failed-Visit-Progress-"
        )
        let storeURL = directory.appending(path: "FarrierFlow.store")

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let graph = try makeVisitGraph(in: container.mainContext, container: container)
            let model = VisitEditorModel(
                visitID: graph.visitID,
                in: container,
                saving: { _, _ in throw VisitEditorTestFailure.unavailable }
            )
            model.load()

            var draft = try #require(model.draft)
            let miloIndex = try horseIndex(named: "Milo", in: draft)
            draft.horses[miloIndex].outcome = .serviced
            draft.horses[miloIndex].workNotes = "Unsaved work"
            model.draft = draft

            #expect(!model.saveProgress())
            #expect(model.isDirty)
            #expect(model.draft == draft)

            let verificationContext = ModelContext(container)
            let visit = try #require(
                verificationContext.model(for: graph.visitID) as? Visit
            )
            #expect(visit.completedAt == nil)
            #expect(visit.visitHorses.allSatisfy {
                $0.outcomeRawValue == VisitOutcome.pending.rawValue && $0.workNotes == nil
            })

            let unrelatedContext = ModelContext(container)
            let client = try #require(unrelatedContext.fetch(FetchDescriptor<Client>()).first)
            client.notes = "Unrelated later save"
            try DomainGraphValidator.save(unrelatedContext)
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            let visit = try #require(context.fetch(FetchDescriptor<Visit>()).first)

            #expect(visit.visitHorses.allSatisfy {
                $0.outcomeRawValue == VisitOutcome.pending.rawValue && $0.workNotes == nil
            })
            try DomainGraphValidator.validateAll(in: context)
        }
    }

    @Test
    func directSaveProgressRollbackDoesNotLeakMutatedValuesIntoLaterSaveOrReopen() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Direct-Failed-Visit-Progress-"
        )
        let storeURL = directory.appending(path: "FarrierFlow.store")

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let graph = try makeVisitGraph(in: container.mainContext, container: container)
            let actionContext = ModelContext(container)
            var draft = try VisitSaveUseCase.loadDraft(
                visitID: graph.visitID,
                in: actionContext
            )
            let miloIndex = try horseIndex(named: "Milo", in: draft)
            draft.horses[miloIndex].outcome = .serviced
            draft.horses[miloIndex].workNotes = "Must not persist"
            var observedMutationBeforeFailure = false

            #expect(throws: VisitEditorTestFailure.unavailable) {
                try VisitSaveUseCase.saveProgress(
                    draft: draft,
                    in: actionContext,
                    saving: { context in
                        let visit = try #require(
                            context.model(for: graph.visitID) as? Visit
                        )
                        observedMutationBeforeFailure = visit.visitHorses.contains {
                            $0.outcomeRawValue == VisitOutcome.serviced.rawValue
                                && $0.workNotes == "Must not persist"
                        }
                        throw VisitEditorTestFailure.unavailable
                    }
                )
            }
            #expect(observedMutationBeforeFailure)

            let verificationContext = ModelContext(container)
            let visit = try #require(
                verificationContext.model(for: graph.visitID) as? Visit
            )
            #expect(visit.visitHorses.allSatisfy {
                $0.outcomeRawValue == VisitOutcome.pending.rawValue && $0.workNotes == nil
            })

            let unrelatedContext = ModelContext(container)
            let client = try #require(unrelatedContext.fetch(FetchDescriptor<Client>()).first)
            client.notes = "Later save after direct VisitSaveUseCase failure"
            try DomainGraphValidator.save(unrelatedContext)
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            let visit = try #require(context.fetch(FetchDescriptor<Visit>()).first)

            #expect(visit.visitHorses.allSatisfy {
                $0.outcomeRawValue == VisitOutcome.pending.rawValue && $0.workNotes == nil
            })
            try DomainGraphValidator.validateAll(in: context)
        }
    }

    @Test
    func invalidWorkNotesKeepProgressSaveUnavailableAndDiscardRestoresBaseline() throws {
        let graph = try makeVisitGraph()
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()
        let baseline = try #require(model.lastSavedDraft)

        var draft = try #require(model.draft)
        let miloIndex = try horseIndex(named: "Milo", in: draft)
        draft.horses[miloIndex].outcome = .notServiced
        draft.horses[miloIndex].workNotes = "Cannot be stored"
        model.draft = draft

        #expect(!model.canSaveProgress)
        #expect(!model.saveProgress())
        #expect(model.isDirty)

        model.discardUnsavedChanges()

        #expect(model.draft == baseline)
        #expect(!model.isDirty)
    }

    @Test
    func completionPersistsDraftAndCompletedAtTogether() throws {
        let graph = try makeVisitGraph()
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()

        var draft = try #require(model.draft)
        let miloIndex = try horseIndex(named: "Milo", in: draft)
        let scoutIndex = try horseIndex(named: "Scout", in: draft)
        draft.horses[miloIndex].outcome = .serviced
        draft.horses[miloIndex].workNotes = "  Applied front shoes  "
        draft.horses[scoutIndex].outcome = .notServiced
        model.draft = draft

        let completedAt = Date(timeIntervalSinceReferenceDate: 200)
        #expect(model.canComplete)
        #expect(model.completeVisit(at: completedAt))
        #expect(!model.isDirty)

        let context = ModelContext(graph.container)
        let visit = try #require(context.model(for: graph.visitID) as? Visit)
        #expect(visit.completedAt == completedAt)
        #expect(visit.visitHorses.contains {
            $0.outcomeRawValue == VisitOutcome.serviced.rawValue
                && $0.workNotes == "Applied front shoes"
        })
        try DomainGraphValidator.validateAll(in: context)
    }

    @Test(arguments: [
        [VisitOutcome.pending, .serviced],
        [.notServiced, .notServiced],
    ])
    func completionRejectsIncompleteOutcomes(_ outcomes: [VisitOutcome]) throws {
        let graph = try makeVisitGraph()
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()

        var draft = try #require(model.draft)
        for index in draft.horses.indices {
            draft.horses[index].outcome = outcomes[index]
        }
        model.draft = draft

        #expect(!model.canComplete)
        #expect(!model.completeVisit(at: Date(timeIntervalSinceReferenceDate: 200)))

        let context = ModelContext(graph.container)
        let visit = try #require(context.model(for: graph.visitID) as? Visit)
        #expect(visit.completedAt == nil)
    }

    @Test
    func failedCompletionPreservesDirtyDraftAndRollsBackPersistedValues() throws {
        let graph = try makeVisitGraph()
        let model = VisitEditorModel(
            visitID: graph.visitID,
            in: graph.container,
            completing: { _, _, _ in throw VisitEditorTestFailure.unavailable }
        )
        model.load()

        var draft = try #require(model.draft)
        let miloIndex = try horseIndex(named: "Milo", in: draft)
        let scoutIndex = try horseIndex(named: "Scout", in: draft)
        draft.horses[miloIndex].outcome = .serviced
        draft.horses[miloIndex].workNotes = "Unsaved completion"
        draft.horses[scoutIndex].outcome = .notServiced
        model.draft = draft

        #expect(!model.completeVisit(at: Date(timeIntervalSinceReferenceDate: 200)))
        #expect(model.isDirty)
        #expect(model.draft == draft)

        let context = ModelContext(graph.container)
        let visit = try #require(context.model(for: graph.visitID) as? Visit)
        #expect(visit.completedAt == nil)
        #expect(visit.visitHorses.allSatisfy {
            $0.outcomeRawValue == VisitOutcome.pending.rawValue && $0.workNotes == nil
        })
    }

    @Test
    func directCompletionRollbackRestoresNilTimestampAndPriorOutcomes() throws {
        let graph = try makeVisitGraph()
        let actionContext = ModelContext(graph.container)
        var draft = try VisitSaveUseCase.loadDraft(visitID: graph.visitID, in: actionContext)
        let miloIndex = try horseIndex(named: "Milo", in: draft)
        let scoutIndex = try horseIndex(named: "Scout", in: draft)
        draft.horses[miloIndex].outcome = .serviced
        draft.horses[scoutIndex].outcome = .notServiced
        var observedCompletedMutation = false

        #expect(throws: VisitEditorTestFailure.unavailable) {
            try VisitSaveUseCase.complete(
                draft: draft,
                completedAt: Date(timeIntervalSinceReferenceDate: 200),
                in: actionContext,
                saving: { context in
                    let visit = try #require(context.model(for: graph.visitID) as? Visit)
                    observedCompletedMutation = visit.completedAt != nil
                        && visit.visitHorses.contains {
                            $0.outcomeRawValue == VisitOutcome.serviced.rawValue
                        }
                    throw VisitEditorTestFailure.unavailable
                }
            )
        }
        #expect(observedCompletedMutation)

        let verificationContext = ModelContext(graph.container)
        let visit = try #require(verificationContext.model(for: graph.visitID) as? Visit)
        #expect(visit.completedAt == nil)
        #expect(visit.visitHorses.allSatisfy {
            $0.outcomeRawValue == VisitOutcome.pending.rawValue && $0.workNotes == nil
        })
    }

    @Test
    func completionRejectsNotesOnNotServicedHorseAndTimeBeforeVisitStart() throws {
        let graph = try makeVisitGraph()
        let model = VisitEditorModel(visitID: graph.visitID, in: graph.container)
        model.load()

        var draft = try #require(model.draft)
        let miloIndex = try horseIndex(named: "Milo", in: draft)
        let scoutIndex = try horseIndex(named: "Scout", in: draft)
        let miloWorkItem = try #require(draft.horses[miloIndex].workItems.first)
        draft.horses[miloIndex].outcome = .notServiced
        draft.horses[miloIndex].workNotes = "Cannot remain"
        draft.horses[miloIndex].workItems = []
        draft.horses[scoutIndex].outcome = .serviced
        draft.horses[scoutIndex].workItems = [
            WorkItemDraft(
                serviceID: miloWorkItem.serviceID,
                serviceNameSnapshot: miloWorkItem.serviceNameSnapshot,
                amountMinorUnits: miloWorkItem.amountMinorUnits
            ),
        ]
        model.draft = draft
        #expect(!model.canComplete)
        #expect(!model.completeVisit(at: Date(timeIntervalSinceReferenceDate: 200)))

        draft.horses[miloIndex].workNotes = ""
        model.draft = draft
        #expect(model.canComplete)
        #expect(!model.completeVisit(at: Date(timeIntervalSinceReferenceDate: 99)))

        let context = ModelContext(graph.container)
        let visit = try #require(context.model(for: graph.visitID) as? Visit)
        #expect(visit.completedAt == nil)
    }

    @Test
    func correctionRejectsPendingAndPreservesCompletionMetadataAfterSave() throws {
        let graph = try makeVisitGraph()
        let completedAt = Date(timeIntervalSinceReferenceDate: 200)
        try completeVisit(graph: graph, completedAt: completedAt)

        let model = VisitEditorModel(
            visitID: graph.visitID,
            in: graph.container,
            mode: .correction
        )
        model.load()
        var draft = try #require(model.draft)
        let miloIndex = try horseIndex(named: "Milo", in: draft)
        draft.horses[miloIndex].outcome = .pending
        model.draft = draft

        #expect(!model.canSaveCorrection)
        #expect(!model.saveCorrection())

        draft.horses[miloIndex].outcome = .serviced
        draft.horses[miloIndex].workNotes = "Corrected work notes"
        model.draft = draft
        #expect(model.canSaveCorrection)
        #expect(model.saveCorrection())

        let context = ModelContext(graph.container)
        let visit = try #require(context.model(for: graph.visitID) as? Visit)
        #expect(visit.completedAt == completedAt)
        #expect(visit.startedAt == Date(timeIntervalSinceReferenceDate: 100))
        #expect(visit.serviceLocationNameSnapshot == "North Field")
        #expect(visit.serviceLocationAddressSnapshot == nil)
        #expect(visit.appointment?.persistentModelID == graph.appointmentID)
        #expect(visit.barn?.persistentModelID == graph.barnID)
        #expect(visit.visitHorses.count == 2)
    }

    @Test
    func invoicedWorkLocksCompletedVisitCorrectionBeforeLoadingItsDraft() throws {
        let graph = try makeVisitGraph()
        try completeVisit(
            graph: graph,
            completedAt: Date(timeIntervalSinceReferenceDate: 200)
        )
        let context = ModelContext(graph.container)
        let visit = try #require(context.model(for: graph.visitID) as? Visit)
        let servicedVisitHorse = try #require(
            visit.visitHorses.first(where: { $0.horse?.name == "Milo" })
        )
        let client = try #require(servicedVisitHorse.horse?.client)
        let workItem = try #require(servicedVisitHorse.workItems.first)
        let profile = ModelFixtures.makeBusinessProfile(
            nextInvoiceNumber: 2,
            in: context
        )
        let invoice = ModelFixtures.makeInvoice(
            number: 1,
            client: client,
            businessProfile: profile,
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

        #expect(throws: VisitSaveError.invoicedVisitCannotBeCorrected) {
            _ = try VisitSaveUseCase.editorMode(
                visitID: graph.visitID,
                in: ModelContext(graph.container)
            )
        }
        #expect(throws: VisitSaveError.invoicedVisitCannotBeCorrected) {
            _ = try VisitSaveUseCase.loadDraft(
                visitID: graph.visitID,
                in: ModelContext(graph.container)
            )
        }

        let model = VisitEditorModel(
            visitID: graph.visitID,
            in: graph.container,
            mode: .correction
        )
        model.load()

        #expect(model.loadState == .failed)
        #expect(model.draft == nil)
    }

    @Test
    func backgroundFailureDefersItsErrorUntilTheSameProcessBecomesActive() throws {
        let graph = try makeVisitGraph()
        let model = VisitEditorModel(
            visitID: graph.visitID,
            in: graph.container,
            saving: { _, _ in throw VisitEditorTestFailure.unavailable }
        )
        model.load()
        var draft = try #require(model.draft)
        let miloIndex = try horseIndex(named: "Milo", in: draft)
        draft.horses[miloIndex].outcome = .serviced
        model.draft = draft

        #expect(!model.saveProgressForBackground())
        #expect(model.isDirty)
        #expect(model.alert == nil)

        model.surfacePendingBackgroundSaveErrorIfNeeded()

        #expect(model.alert?.title == "Couldn’t Save Progress")
        #expect(model.draft == draft)
    }

    @Test
    func discardingInProgressVisitCascadesOnlyItsHorseMemberships() throws {
        let graph = try makeVisitGraph()
        let context = ModelContext(graph.container)

        try VisitDiscardUseCase.discard(visitID: graph.visitID, in: context)

        let verificationContext = ModelContext(graph.container)
        #expect(try verificationContext.fetch(FetchDescriptor<Visit>()).isEmpty)
        #expect(try verificationContext.fetch(FetchDescriptor<VisitHorse>()).isEmpty)
        #expect(try verificationContext.fetch(FetchDescriptor<WorkItem>()).isEmpty)
        #expect(try verificationContext.fetch(FetchDescriptor<Appointment>()).count == 1)
        #expect(try verificationContext.fetch(FetchDescriptor<AppointmentHorse>()).count == 2)
        #expect(try verificationContext.fetch(FetchDescriptor<Barn>()).count == 1)
        #expect(try verificationContext.fetch(FetchDescriptor<Horse>()).count == 2)
        #expect(try verificationContext.fetch(FetchDescriptor<Client>()).count == 1)
        try DomainGraphValidator.validateAll(in: verificationContext)
    }

    @Test
    func completedVisitCannotBeDiscarded() throws {
        let graph = try makeVisitGraph()
        try completeVisit(
            graph: graph,
            completedAt: Date(timeIntervalSinceReferenceDate: 200)
        )

        let context = ModelContext(graph.container)
        #expect(throws: RecordDeletionBlock.completedVisitCannotBeDeleted) {
            try VisitDiscardUseCase.discard(visitID: graph.visitID, in: context)
        }
    }

    @Test
    func correctedCompletedVisitSurvivesStoreReopeningWithImmutableMetadata() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-Completed-Visit-Correction-"
        )
        let storeURL = directory.appending(path: "FarrierFlow.store")
        let expectedStartedAt = Date(timeIntervalSinceReferenceDate: 100)
        let expectedCompletedAt = Date(timeIntervalSinceReferenceDate: 200)

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let graph = try makeVisitGraph(in: container.mainContext, container: container)
            try completeVisit(graph: graph, completedAt: expectedCompletedAt)

            let actionContext = ModelContext(container)
            var correction = try VisitSaveUseCase.loadDraft(
                visitID: graph.visitID,
                in: actionContext
            )
            let miloIndex = try horseIndex(named: "Milo", in: correction)
            let scoutIndex = try horseIndex(named: "Scout", in: correction)
            let miloWorkItem = try #require(correction.horses[miloIndex].workItems.first)
            correction.horses[miloIndex].outcome = .notServiced
            correction.horses[miloIndex].workNotes = ""
            correction.horses[miloIndex].workItems = []
            correction.horses[scoutIndex].outcome = .serviced
            correction.horses[scoutIndex].workNotes = "Corrected work"
            correction.horses[scoutIndex].workItems = [
                WorkItemDraft(
                    serviceID: miloWorkItem.serviceID,
                    serviceNameSnapshot: miloWorkItem.serviceNameSnapshot,
                    amountMinorUnits: miloWorkItem.amountMinorUnits
                ),
            ]
            _ = try VisitSaveUseCase.saveCorrection(draft: correction, in: actionContext)
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            let context = ModelContext(container)
            let visit = try #require(context.fetch(FetchDescriptor<Visit>()).first)
            #expect(visit.startedAt == expectedStartedAt)
            #expect(visit.completedAt == expectedCompletedAt)
            #expect(visit.serviceLocationNameSnapshot == "North Field")
            #expect(visit.appointment != nil)
            #expect(visit.barn != nil)
            #expect(visit.visitHorses.count == 2)
            #expect(visit.visitHorses.contains { $0.workNotes == "Corrected work" })
            try DomainGraphValidator.validateAll(in: context)
        }
    }

    private func makeVisitGraph() throws -> VisitEditorGraph {
        let container = try ModelContainerFactory.inMemoryTest()
        return try makeVisitGraph(in: container.mainContext, container: container)
    }

    private func makeVisitGraph(
        in context: ModelContext,
        container: ModelContainer
    ) throws -> VisitEditorGraph {
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)

        let firstHorse = Horse(name: "Milo", client: client, currentBarn: barn)
        let secondHorse = Horse(name: "Scout", client: client, currentBarn: barn)
        context.insert(firstHorse)
        context.insert(secondHorse)
        client.horses.append(contentsOf: [firstHorse, secondHorse])
        barn.horses.append(contentsOf: [firstHorse, secondHorse])

        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [firstHorse, secondHorse],
            in: context
        )
        let defaultService = ModelFixtures.makeService(
            name: "Front Shoes",
            defaultAmountMinorUnits: 12_500,
            in: context
        )
        firstHorse.defaultService = defaultService
        defaultService.horsesUsingAsDefault.append(firstHorse)
        try DomainGraphValidator.save(context)
        let visitID = try VisitStartUseCase.start(
            appointmentID: appointment.persistentModelID,
            now: Date(timeIntervalSinceReferenceDate: 100),
            in: container
        )

        return VisitEditorGraph(
            container: container,
            visitID: visitID,
            appointmentID: appointment.persistentModelID,
            barnID: barn.persistentModelID
        )
    }

    private func completeVisit(
        graph: VisitEditorGraph,
        completedAt: Date
    ) throws {
        let context = ModelContext(graph.container)
        var draft = try VisitSaveUseCase.loadDraft(visitID: graph.visitID, in: context)
        let miloIndex = try horseIndex(named: "Milo", in: draft)
        let scoutIndex = try horseIndex(named: "Scout", in: draft)
        draft.horses[miloIndex].outcome = .serviced
        draft.horses[scoutIndex].outcome = .notServiced
        _ = try VisitSaveUseCase.complete(
            draft: draft,
            completedAt: completedAt,
            in: context
        )
    }

    private func horseIndex(named horseName: String, in draft: VisitDraft) throws -> Int {
        try #require(draft.horses.firstIndex(where: { $0.horseName == horseName }))
    }
}

private struct VisitEditorGraph {
    let container: ModelContainer
    let visitID: PersistentIdentifier
    let appointmentID: PersistentIdentifier
    let barnID: PersistentIdentifier
}

private enum VisitEditorTestFailure: Error, Equatable {
    case unavailable
}
