import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Export snapshot builder", .serialized)
@MainActor
struct ExportSnapshotBuilderTests {
    @Test
    func projectsEveryApprovedEntityRelationshipAndInvoiceSnapshot() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()

        let snapshot = try await ExportSnapshotBuilder.build(
            in: graph.context,
            exportContext: graph.exportContext,
            progress: { _ in }
        )

        #expect(snapshot.context == graph.exportContext)
        #expect(snapshot.businessProfiles.count == 1)
        #expect(snapshot.clients.count == 2)
        #expect(snapshot.serviceLocations.count == 2)
        #expect(snapshot.horses.count == 4)
        #expect(snapshot.appointments.count == 2)
        #expect(snapshot.appointmentHorses.count == 4)
        #expect(snapshot.visits.count == 2)
        #expect(snapshot.visitHorses.count == 4)
        #expect(snapshot.photographs.count == 1)
        #expect(snapshot.services.count == 3)
        #expect(snapshot.workItems.count == 2)
        #expect(snapshot.invoices.count == 2)
        #expect(snapshot.invoiceVisits.count == 2)
        #expect(snapshot.invoiceLineItems.count == 2)
        #expect(snapshot.invoiceDocuments.count == 2)

        let milo = try #require(snapshot.horses.first(where: { $0.name == "Current Milo" }))
        let alex = try #require(snapshot.clients.first(where: { $0.name == "Current Alex Carter" }))
        let northField = try #require(snapshot.serviceLocations.first(where: { $0.name == "North Field" }))
        let trim = try #require(snapshot.services.first(where: { $0.name == "Current Trim" }))
        #expect(milo.clientID == alex.id)
        #expect(milo.currentServiceLocationID == northField.id)
        #expect(milo.defaultServiceID == trim.id)
        #expect(snapshot.visitHorses.map(\.outcomeRawValue).sorted() == ["notServiced", "pending", "serviced", "serviced"])
        #expect(snapshot.services.first(where: { $0.name == "Legacy Pads" })?.isArchived == true)
        #expect(snapshot.photographs[0].photographID == ExportTestFixtures.photographID)
        #expect(snapshot.workItems.allSatisfy { $0.invoiceLineItemID != nil })
        #expect(snapshot.invoices.map(\.statusRawValue).sorted() == ["paid", "unpaid"])
        #expect(snapshot.invoices.filter { $0.dueDate == nil }.count == 1)
        #expect(snapshot.invoices.filter { $0.paidAt == nil }.count == 1)
        #expect(snapshot.appointments.allSatisfy { $0.serviceLocationID.entity == .serviceLocation })
        #expect(snapshot.appointmentHorses.allSatisfy {
            $0.appointmentID.entity == .appointment && $0.horseID.entity == .horse
        })
        #expect(snapshot.visits.allSatisfy {
            $0.appointmentID.entity == .appointment
                && $0.serviceLocationID.entity == .serviceLocation
        })
        #expect(snapshot.visitHorses.allSatisfy {
            $0.visitID.entity == .visit && $0.horseID.entity == .horse
        })
        #expect(snapshot.photographs.allSatisfy { $0.visitHorseID.entity == .visitHorse })
        #expect(snapshot.workItems.allSatisfy {
            $0.serviceID.entity == .service && $0.visitHorseID.entity == .visitHorse
        })
        #expect(snapshot.invoices.allSatisfy { $0.clientID.entity == .client })
        #expect(snapshot.invoiceVisits.allSatisfy {
            $0.invoiceID.entity == .invoice && $0.sourceVisitID.entity == .visit
        })
        #expect(snapshot.invoiceLineItems.allSatisfy {
            $0.invoiceVisitID.entity == .invoiceVisit
                && $0.sourceWorkItemID.entity == .workItem
        })

        let unpaidDocument = try #require(
            snapshot.invoiceDocuments.first(where: { $0.relativePath == "Invoices/Invoice-0001.pdf" })
        )
        #expect(unpaidDocument.content.number == "0001")
        #expect(unpaidDocument.content.businessName == "Carter Farrier Service")
        #expect(unpaidDocument.content.clientName == "Alex Carter")
        #expect(unpaidDocument.content.visits[0].location == "North Field")
        #expect(unpaidDocument.content.visits[0].lineItems == [
            .init(horseName: "Milo", serviceName: "Trim", amountMinorUnits: 6_500),
        ])
        #expect(unpaidDocument.content.totalMinorUnits == 6_500)
    }

    @Test(arguments: MissingRelationship.allCases)
    func rejectsMissingRequiredRelationshipsBeforeProjection(
        missingRelationship: MissingRelationship
    ) async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let expectedViolation = missingRelationship.remove(from: graph)
        var progress = [ExportSnapshotProgress]()

        await #expect(throws: ExportSnapshotError.invalidGraph(expectedViolation)) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func rejectsBrokenInverseNormalizedBySwiftDataBeforeProjection() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let owner = graph.visitHorses[0]
        let service = Service(name: "Inverse Test", defaultAmountMinorUnits: 1_000)
        let workItem = WorkItem(
            serviceNameSnapshot: "Inverse Test",
            amountMinorUnits: 1_000,
            service: service,
            visitHorse: owner
        )
        graph.context.insert(service)
        graph.context.insert(workItem)
        // SwiftData repairs the one-sided inverse mutation by clearing the forward link.
        service.setValue(forKey: \Service.workItems, to: [] as [WorkItem])
        #expect(workItem.service == nil)
        #expect(service.workItems.isEmpty)
        var progress = [ExportSnapshotProgress]()

        await #expect(
            throws: ExportSnapshotError.invalidGraph(.workItemMissingService)
        ) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test(arguments: PublicInverseMutation.rejectedCases)
    func rejectsEveryFeasibleInverseMutationRejectedByCanonicalValidation(
        mutation: PublicInverseMutation
    ) async throws {
        let canonicalGraph = try ExportTestFixtures.makeCompleteGraph()
        try mutation.apply(to: canonicalGraph)
        #expect(throws: (any Error).self) {
            try DomainGraphValidator.validateAll(in: canonicalGraph.context)
        }

        let exportGraph = try ExportTestFixtures.makeCompleteGraph()
        try mutation.apply(to: exportGraph)
        var progress = [ExportSnapshotProgress]()
        await #expect(throws: (any Error).self) {
            _ = try await ExportSnapshotBuilder.build(
                in: exportGraph.context,
                exportContext: exportGraph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func rejectsDanglingRequiredTargetBeforeReportingProgress() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let client = Client(name: "Deleted Owner")
        let horse = Horse(
            name: "Dangling Required",
            client: client,
            currentBarn: graph.barns[0]
        )
        graph.context.insert(client)
        graph.context.insert(horse)
        client.horses.append(horse)
        graph.barns[0].horses.append(horse)
        try DomainGraphValidator.save(graph.context)
        let deletedID = client.persistentModelID
        graph.context.delete(client)
        #expect(horse.client === client)
        #expect(try !graph.context.fetch(FetchDescriptor<Client>()).contains {
            $0.persistentModelID == deletedID
        })
        var progress = [ExportSnapshotProgress]()

        await #expect(
            throws: ExportSnapshotError.missingProjectedRelationship(
                entity: .horse,
                relationship: "client"
            )
        ) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func rejectsDanglingOptionalTargetInsteadOfSilentlyOmittingIt() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let service = ModelFixtures.makeService(
            name: "Deleted Default",
            defaultAmountMinorUnits: 7_500,
            in: graph.context
        )
        let horse = graph.horses[2]
        horse.defaultService = service
        service.horsesUsingAsDefault.append(horse)
        try DomainGraphValidator.save(graph.context)
        let deletedID = service.persistentModelID
        graph.context.delete(service)
        #expect(horse.defaultService === service)
        #expect(try !graph.context.fetch(FetchDescriptor<Service>()).contains {
            $0.persistentModelID == deletedID
        })
        var progress = [ExportSnapshotProgress]()

        await #expect(
            throws: ExportSnapshotError.missingProjectedRelationship(
                entity: .horse,
                relationship: "defaultService"
            )
        ) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func acceptsReassignedOptionalRelationshipBeforeDeletingItsSavedTarget() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let oldService = ModelFixtures.makeService(
            name: "Old Default",
            defaultAmountMinorUnits: 7_000,
            in: graph.context
        )
        let replacement = ModelFixtures.makeService(
            name: "New Default",
            defaultAmountMinorUnits: 8_000,
            in: graph.context
        )
        let horse = graph.horses[2]
        horse.defaultService = oldService
        oldService.horsesUsingAsDefault.append(horse)
        try DomainGraphValidator.save(graph.context)

        oldService.horsesUsingAsDefault.removeAll { $0 === horse }
        horse.defaultService = replacement
        replacement.horsesUsingAsDefault.append(horse)
        graph.context.delete(oldService)
        var progress = [ExportSnapshotProgress]()

        let snapshot = try await ExportSnapshotBuilder.build(
            in: graph.context,
            exportContext: graph.exportContext,
            progress: { progress.append($0) }
        )

        let exportedHorse = try #require(snapshot.horses.first { $0.name == horse.name })
        let exportedService = try #require(snapshot.services.first { $0.name == replacement.name })
        #expect(exportedHorse.defaultServiceID == exportedService.id)
        #expect(progress.last?.completedRecords == progress.last?.totalRecords)
    }

    @Test
    func acceptsClearedOptionalRelationshipBeforeDeletingItsSavedTarget() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let oldService = ModelFixtures.makeService(
            name: "Cleared Default",
            defaultAmountMinorUnits: 7_000,
            in: graph.context
        )
        let horse = graph.horses[2]
        horse.defaultService = oldService
        oldService.horsesUsingAsDefault.append(horse)
        try DomainGraphValidator.save(graph.context)

        oldService.horsesUsingAsDefault.removeAll { $0 === horse }
        horse.defaultService = nil
        graph.context.delete(oldService)
        var progress = [ExportSnapshotProgress]()

        let snapshot = try await ExportSnapshotBuilder.build(
            in: graph.context,
            exportContext: graph.exportContext,
            progress: { progress.append($0) }
        )

        let exportedHorse = try #require(snapshot.horses.first { $0.name == horse.name })
        #expect(exportedHorse.defaultServiceID == nil)
        #expect(progress.last?.completedRecords == progress.last?.totalRecords)
    }

    @Test
    func rejectsDeletedUnsavedReplacementForSavedOptionalRelationshipBeforeProgress() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let savedService = ModelFixtures.makeService(
            name: "Saved Default",
            defaultAmountMinorUnits: 7_000,
            in: graph.context
        )
        let replacement = ModelFixtures.makeService(
            name: "Unsaved Replacement",
            defaultAmountMinorUnits: 8_000,
            in: graph.context
        )
        let horse = graph.horses[2]
        horse.defaultService = savedService
        savedService.horsesUsingAsDefault.append(horse)
        try DomainGraphValidator.save(graph.context)

        savedService.horsesUsingAsDefault.removeAll { $0 === horse }
        horse.defaultService = replacement
        replacement.horsesUsingAsDefault.append(horse)
        graph.context.delete(replacement)
        #expect(horse.defaultService === replacement)
        var progress = [ExportSnapshotProgress]()

        await #expect(
            throws: ExportSnapshotError.missingProjectedRelationship(
                entity: .horse,
                relationship: "defaultService"
            )
        ) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }

        #expect(progress.isEmpty)
    }

    @Test
    func rejectsDeletedUnsavedReplacementForSavedRequiredRelationshipBeforeProgress() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let savedClient = Client(name: "Saved Client")
        let replacement = Client(name: "Unsaved Replacement Client")
        let horse = Horse(
            name: "Required Replacement Horse",
            client: savedClient,
            currentBarn: graph.barns[0]
        )
        for model in [savedClient, replacement] { graph.context.insert(model) }
        graph.context.insert(horse)
        savedClient.horses.append(horse)
        graph.barns[0].horses.append(horse)
        try DomainGraphValidator.save(graph.context)

        savedClient.horses.removeAll { $0 === horse }
        horse.client = replacement
        replacement.horses.append(horse)
        graph.context.delete(replacement)
        #expect(horse.client === replacement)
        var progress = [ExportSnapshotProgress]()

        await #expect(
            throws: ExportSnapshotError.missingProjectedRelationship(
                entity: .horse,
                relationship: "client"
            )
        ) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }

        #expect(progress.isEmpty)
    }

    @Test
    func rejectsDuplicateUniqueRelationshipBeforeProjection() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let appointment = graph.appointments[0]
        let horse = try #require(appointment.appointmentHorses[0].horse)
        let duplicate = AppointmentHorse(appointment: appointment, horse: horse)
        graph.context.insert(duplicate)
        appointment.appointmentHorses.append(duplicate)
        horse.appointmentHorses.append(duplicate)
        var progress = [ExportSnapshotProgress]()

        await #expect(throws: ExportSnapshotError.invalidGraph(.duplicateHorseMembership)) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func rejectsUnknownVisitOutcomeBeforeProjection() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        graph.visitHorses[0].outcomeRawValue = "cancelled"
        var progress = [ExportSnapshotProgress]()

        await #expect(throws: ExportSnapshotError.unsupportedVisitOutcome("cancelled")) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func rejectsUnknownInvoiceStatusBeforeProjection() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        graph.invoices[0].statusRawValue = "void"
        var progress = [ExportSnapshotProgress]()

        await #expect(throws: ExportSnapshotError.unsupportedInvoiceStatus("void")) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func rejectsInvalidPaidStateBeforeProjection() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        graph.invoices[0].paidAt = Date(timeIntervalSinceReferenceDate: 5_000)
        var progress = [ExportSnapshotProgress]()

        await #expect(throws: ExportSnapshotError.invalidInvoicePaymentState) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func rejectsNegativeMoneyBeforeProjection() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        graph.services[0].defaultAmountMinorUnits = -1
        var progress = [ExportSnapshotProgress]()

        await #expect(throws: ExportSnapshotError.invalidGraph(.serviceAmountNegative)) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func rejectsInconsistentCurrencyBeforeProjection() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        graph.workItems[0].currencyCode = "EUR"
        var progress = [ExportSnapshotProgress]()

        await #expect(throws: ExportSnapshotError.invalidGraph(.workItemCurrencyInvalid)) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func rejectsInvoiceSequenceThatDoesNotLeadIssuedNumbersBeforeProjection() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        graph.profile.nextInvoiceNumber = 2
        var progress = [ExportSnapshotProgress]()

        await #expect(
            throws: ExportSnapshotError.invalidGraph(.businessProfileSequenceInvalid)
        ) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func rejectsDuplicatePhotographUUIDBeforeProjection() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let owner = try #require(graph.photograph.visitHorse)
        let duplicate = Photograph(
            id: ExportTestFixtures.photographID,
            createdAt: Date(timeIntervalSinceReferenceDate: 1_300),
            pixelWidth: 1_000,
            pixelHeight: 800,
            byteCount: 21_000,
            visitHorse: owner
        )
        graph.context.insert(duplicate)
        owner.photographs.append(duplicate)
        var progress = [ExportSnapshotProgress]()

        await #expect(throws: ExportSnapshotError.invalidGraph(.duplicatePhotographID)) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func buildsDeterministicallyForEqualVisibleValuesWithoutSerializingPersistentIDs() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let firstTwin = Client(name: "Same Client", phone: "555-0110")
        let secondTwin = Client(name: "Same Client", phone: "555-0110")
        graph.context.insert(firstTwin)
        graph.context.insert(secondTwin)
        try DomainGraphValidator.save(graph.context)
        #expect(!graph.context.hasChanges)

        let first = try await ExportSnapshotBuilder.build(
            in: graph.context,
            exportContext: graph.exportContext,
            progress: { _ in }
        )
        let second = try await ExportSnapshotBuilder.build(
            in: graph.context,
            exportContext: graph.exportContext,
            progress: { _ in }
        )

        #expect(first == second)
        #expect(!graph.context.hasChanges)

        let tables = try ExportCSVProjector.tables(
            from: first,
            photographResults: [ExportTestFixtures.photographID: .unavailable]
        )
        let serialized = try tables.reduce(into: "") { result, table in
            let data = try ExportCSVWriter().encode(table)
            result += try #require(String(data: data, encoding: .utf8))
        }
        for persistentID in try persistentIDDescriptions(in: graph.context) {
            #expect(!serialized.contains(persistentID))
        }
    }

    @Test
    func reportsEveryRecordAtBatchSizeOne() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        var progress = [ExportSnapshotProgress]()

        _ = try await ExportSnapshotBuilder.build(
            in: graph.context,
            exportContext: graph.exportContext,
            batchSize: 1,
            progress: { progress.append($0) }
        )

        let expectedTotal = 33
        #expect(progress == (0...expectedTotal).map {
            ExportSnapshotProgress(completedRecords: $0, totalRecords: expectedTotal)
        })
    }

    @Test
    func acceptsCancellationBetweenBatchSizeOneGroupsWithoutReturningAPartialSnapshot() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        var progress = [ExportSnapshotProgress]()
        let holder = ExportSnapshotTaskHolder()

        holder.task = Task { @MainActor in
            try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                batchSize: 1,
                progress: { update in
                    progress.append(update)
                    if update.completedRecords == 1 {
                        holder.task?.cancel()
                    }
                }
            )
        }
        let task = try #require(holder.task)
        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }

        #expect(progress.last == ExportSnapshotProgress(completedRecords: 1, totalRecords: 33))
    }

    @Test
    func acceptsCancellationAfterBoundedNestedInvoiceConstructionBegins() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let additionalLineItemCount = 64
        try ExportTestFixtures.appendInvoiceLineItems(
            count: additionalLineItemCount,
            to: graph
        )
        let sourceLineItems = try invoiceLineItemValues(in: graph.context)
        let originalRecordsBeforeInvoices = 27
        let addedRecordsBeforeInvoices = additionalLineItemCount * 2
        let recordsBeforeInvoices = originalRecordsBeforeInvoices + addedRecordsBeforeInvoices
        let totalRecords = 33 + additionalLineItemCount * 3
        // With 65 nested items at batch size 64, these turns pass the outer
        // invoice checkpoint and enter nested visit/line-item document work.
        let cancellationTurnCount = 20
        var progress = [ExportSnapshotProgress]()
        let holder = ExportSnapshotTaskHolder()

        holder.task = Task { @MainActor in
            try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                batchSize: 64,
                progress: { update in
                    progress.append(update)
                    if update.completedRecords == recordsBeforeInvoices {
                        holder.canceller = Task { @MainActor in
                            for _ in 0..<cancellationTurnCount {
                                await Task.yield()
                            }
                            holder.task?.cancel()
                        }
                    }
                }
            )
        }
        let task = try #require(holder.task)
        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        await holder.canceller?.value

        #expect(progress.last == ExportSnapshotProgress(
            completedRecords: recordsBeforeInvoices,
            totalRecords: totalRecords
        ))
        #expect(try invoiceLineItemValues(in: graph.context) == sourceLineItems)
    }

    @Test
    func preCancelledBuildStopsBeforeInvalidGraphValidation() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        graph.services[0].defaultAmountMinorUnits = -1
        var progress = [ExportSnapshotProgress]()
        let holder = ExportSnapshotTaskHolder()

        holder.task = Task { @MainActor in
            try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                batchSize: 1,
                progress: { progress.append($0) }
            )
        }
        let task = try #require(holder.task)
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        #expect(progress.isEmpty)
    }

    @Test
    func acceptsCancellationWhilePagingMoreThanTwoHundredRecordsBeforeProgress() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let additionalServiceCount = 401
        for index in 1...additionalServiceCount {
            _ = ModelFixtures.makeService(
                name: "Paged Service \(index)",
                defaultAmountMinorUnits: Int64(index),
                in: graph.context
            )
        }
        try DomainGraphValidator.save(graph.context)
        var progress = [ExportSnapshotProgress]()
        let holder = ExportSnapshotTaskHolder()

        holder.task = Task { @MainActor in
            try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                batchSize: 200,
                progress: { progress.append($0) }
            )
        }
        holder.canceller = Task { @MainActor in
            // Two dangling-hint checkpoints plus nine four-checkpoint entity fetches
            // put the service fetch at turn 39. Turn 43 is between its first and
            // second 200-record pages, before any projection progress is legal.
            for _ in 0..<43 {
                await Task.yield()
            }
            holder.task?.cancel()
        }
        let task = try #require(holder.task)
        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }
        await holder.canceller?.value

        #expect(progress.isEmpty)
        #expect(try graph.context.fetchCount(FetchDescriptor<Service>()) == 404)
        #expect(graph.context.hasChanges == false)
    }

    @Test
    func projectsEveryRecordExactlyOnceAcrossMoreThanTwoFetchGroups() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let additionalServiceCount = 401
        let additionalNames = (1...additionalServiceCount).map { "Exact Service \($0)" }
        for (index, name) in additionalNames.enumerated() {
            _ = ModelFixtures.makeService(
                name: name,
                defaultAmountMinorUnits: Int64(index + 1),
                in: graph.context
            )
        }
        try DomainGraphValidator.save(graph.context)
        var progress = [ExportSnapshotProgress]()

        let snapshot = try await ExportSnapshotBuilder.build(
            in: graph.context,
            exportContext: graph.exportContext,
            batchSize: 200,
            progress: { progress.append($0) }
        )

        let expectedNames = Set(graph.services.map(\.name) + additionalNames)
        let actualNames = snapshot.services.map(\.name)
        #expect(actualNames.count == 404)
        #expect(Set(actualNames) == expectedNames)
        #expect(Set(actualNames).count == actualNames.count)
        #expect(progress.last == ExportSnapshotProgress(completedRecords: 434, totalRecords: 434))
    }

    @Test
    func rejectsMembershipMutationDuringGroupedFetchBeforeProgress() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let additionalServiceCount = 401
        var serviceToDelete: Service?
        for index in 1...additionalServiceCount {
            let service = ModelFixtures.makeService(
                name: "Mutable Service \(index)",
                defaultAmountMinorUnits: Int64(index),
                in: graph.context
            )
            serviceToDelete = serviceToDelete ?? service
        }
        try DomainGraphValidator.save(graph.context)
        let removedService = try #require(serviceToDelete)
        var progress = [ExportSnapshotProgress]()
        let holder = ExportSnapshotTaskHolder()

        holder.task = Task { @MainActor in
            try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                batchSize: 200,
                progress: { progress.append($0) }
            )
        }
        holder.canceller = Task { @MainActor in
            // The preceding entity membership captures and Service's three bounded ID
            // groups finish before this turn; final membership verification has not.
            for _ in 0..<100 {
                await Task.yield()
            }
            graph.context.delete(removedService)
        }
        let task = try #require(holder.task)
        await #expect(throws: ExportSnapshotError.sourceGraphChanged(.service)) {
            _ = try await task.value
        }
        await holder.canceller?.value

        #expect(progress.isEmpty)
    }

    @Test
    func rejectsEarlyEntityDeletionAfterItsMembershipRecheckBeforeProgress() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let clientToDelete = Client(name: "Post-recheck Client")
        graph.context.insert(clientToDelete)
        for index in 1...401 {
            _ = ModelFixtures.makeService(
                name: "Later Work Service \(index)",
                defaultAmountMinorUnits: Int64(index),
                in: graph.context
            )
        }
        try DomainGraphValidator.save(graph.context)
        var progress = [ExportSnapshotProgress]()
        let holder = ExportSnapshotTaskHolder()

        holder.task = Task { @MainActor in
            try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                batchSize: 200,
                progress: { progress.append($0) }
            )
        }
        holder.canceller = Task { @MainActor in
            // Operation setup and all captures consume 76 yields. Business Profile
            // and Client rechecks finish by turn 88; later entity work is still active.
            for _ in 0..<100 {
                await Task.yield()
            }
            graph.context.delete(clientToDelete)
        }
        let task = try #require(holder.task)
        await #expect(throws: ExportSnapshotError.sourceGraphChanged(.client)) {
            _ = try await task.value
        }
        await holder.canceller?.value

        #expect(progress.isEmpty)
    }

    @Test
    func rejectsSavedEarlyEntityDeletionAfterItsMembershipRecheckBeforeProgress() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        let clientToDelete = Client(name: "Saved Post-recheck Client")
        graph.context.insert(clientToDelete)
        for index in 1...401 {
            _ = ModelFixtures.makeService(
                name: "Later Saved Work Service \(index)",
                defaultAmountMinorUnits: Int64(index),
                in: graph.context
            )
        }
        try DomainGraphValidator.save(graph.context)
        var progress = [ExportSnapshotProgress]()
        let holder = ExportSnapshotTaskHolder()

        holder.task = Task { @MainActor in
            try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                batchSize: 200,
                progress: { progress.append($0) }
            )
        }
        holder.canceller = Task { @MainActor in
            for _ in 0..<100 {
                await Task.yield()
            }
            graph.context.delete(clientToDelete)
            do {
                try graph.context.save()
            } catch {
                holder.mutationError = error
            }
        }
        let task = try #require(holder.task)
        await #expect(throws: ExportSnapshotError.sourceGraphChanged(.client)) {
            _ = try await task.value
        }
        await holder.canceller?.value

        #expect(holder.mutationError == nil)
        #expect(progress.isEmpty)
    }

    @Test
    func rejectsInvalidBatchSizeBeforeFetchingOrReportingProgress() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        var progress = [ExportSnapshotProgress]()

        await #expect(throws: ExportSnapshotError.invalidBatchSize(0)) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                batchSize: 0,
                progress: { progress.append($0) }
            )
        }
        #expect(progress.isEmpty)
    }

    @Test
    func rejectsBatchSizeAboveMaximumBeforeFetchingOrReportingProgress() async throws {
        let graph = try ExportTestFixtures.makeCompleteGraph()
        var progress = [ExportSnapshotProgress]()

        await #expect(throws: ExportSnapshotError.batchSizeExceedsMaximum(201)) {
            _ = try await ExportSnapshotBuilder.build(
                in: graph.context,
                exportContext: graph.exportContext,
                batchSize: 201,
                progress: { progress.append($0) }
            )
        }

        #expect(progress.isEmpty)
        #expect(graph.context.hasChanges == false)
    }

    private func persistentIDDescriptions(in context: ModelContext) throws -> [String] {
        try persistentIDDescriptions(of: BusinessProfile.self, in: context)
            + persistentIDDescriptions(of: Client.self, in: context)
            + persistentIDDescriptions(of: Barn.self, in: context)
            + persistentIDDescriptions(of: Horse.self, in: context)
            + persistentIDDescriptions(of: Appointment.self, in: context)
            + persistentIDDescriptions(of: AppointmentHorse.self, in: context)
            + persistentIDDescriptions(of: Visit.self, in: context)
            + persistentIDDescriptions(of: VisitHorse.self, in: context)
            + persistentIDDescriptions(of: Photograph.self, in: context)
            + persistentIDDescriptions(of: Service.self, in: context)
            + persistentIDDescriptions(of: WorkItem.self, in: context)
            + persistentIDDescriptions(of: Invoice.self, in: context)
            + persistentIDDescriptions(of: InvoiceVisit.self, in: context)
            + persistentIDDescriptions(of: InvoiceLineItem.self, in: context)
    }

    private func persistentIDDescriptions<Model: PersistentModel>(
        of type: Model.Type,
        in context: ModelContext
    ) throws -> [String] {
        try context.fetch(FetchDescriptor<Model>()).map {
            String(describing: $0.persistentModelID)
        }
    }

    private func invoiceLineItemValues(in context: ModelContext) throws -> [String] {
        try context.fetch(FetchDescriptor<InvoiceLineItem>()).map {
            "\($0.horseNameSnapshot)|\($0.serviceNameSnapshot)|\($0.amountMinorUnits)"
        }.sorted()
    }
}

@MainActor
private final class ExportSnapshotTaskHolder {
    var task: Task<ExportSnapshot, Error>?
    var canceller: Task<Void, Never>?
    var mutationError: Error?
}

enum PublicInverseMutation: CaseIterable, CustomTestStringConvertible {
    case clientHorses
    case barnHorses
    case barnAppointments
    case barnVisits
    case serviceWorkItems
    case horseAppointmentHorses
    case horseVisitHorses
    case appointmentHorses
    case appointmentVisit
    case visitHorses
    case visitHorseWorkItems
    case clientInvoices
    case invoiceVisits
    case sourceVisitInvoiceVisits
    case invoiceVisitLineItems
    case workItemInvoiceLineItem
    case visitHorsePhotographs

    static var rejectedCases: [PublicInverseMutation] { allCases }

    var testDescription: String { String(describing: self) }

    @MainActor
    func apply(to graph: CompleteGraph) throws {
        switch self {
        case .clientHorses:
            let client = try #require(graph.horses[0].client)
            client.setValue(forKey: \Client.horses, to: [] as [Horse])
        case .barnHorses:
            let barn = try #require(graph.horses[0].currentBarn)
            barn.setValue(forKey: \Barn.horses, to: [] as [Horse])
        case .barnAppointments:
            let barn = try #require(graph.appointments[0].barn)
            barn.setValue(forKey: \Barn.appointments, to: [] as [Appointment])
        case .barnVisits:
            let barn = try #require(graph.visits[0].barn)
            barn.setValue(forKey: \Barn.visits, to: [] as [Visit])
        case .serviceWorkItems:
            let service = try #require(graph.workItems[0].service)
            service.setValue(forKey: \Service.workItems, to: [] as [WorkItem])
        case .horseAppointmentHorses:
            let membership = try #require(graph.appointments[0].appointmentHorses.first)
            let horse = try #require(membership.horse)
            horse.setValue(forKey: \Horse.appointmentHorses, to: [] as [AppointmentHorse])
        case .horseVisitHorses:
            let horse = try #require(graph.visitHorses[0].horse)
            horse.setValue(forKey: \Horse.visitHorses, to: [] as [VisitHorse])
        case .appointmentHorses:
            graph.appointments[0].setValue(
                forKey: \Appointment.appointmentHorses,
                to: [] as [AppointmentHorse]
            )
        case .appointmentVisit:
            graph.appointments[0].setValue(forKey: \Appointment.visit, to: nil as Visit?)
        case .visitHorses:
            graph.visits[0].setValue(forKey: \Visit.visitHorses, to: [] as [VisitHorse])
        case .visitHorseWorkItems:
            let owner = try #require(graph.workItems[0].visitHorse)
            owner.setValue(forKey: \VisitHorse.workItems, to: [] as [WorkItem])
        case .clientInvoices:
            let client = try #require(graph.invoices[0].client)
            client.setValue(forKey: \Client.invoices, to: [] as [Invoice])
        case .invoiceVisits:
            graph.invoices[0].setValue(forKey: \Invoice.invoiceVisits, to: [] as [InvoiceVisit])
        case .sourceVisitInvoiceVisits:
            let sourceVisit = try #require(graph.invoices[0].invoiceVisits[0].sourceVisit)
            sourceVisit.setValue(forKey: \Visit.invoiceVisits, to: [] as [InvoiceVisit])
        case .invoiceVisitLineItems:
            let invoiceVisit = graph.invoices[0].invoiceVisits[0]
            invoiceVisit.setValue(forKey: \InvoiceVisit.lineItems, to: [] as [InvoiceLineItem])
        case .workItemInvoiceLineItem:
            let invoiceVisit = try #require(graph.invoices[0].invoiceVisits.first)
            let lineItem = try #require(invoiceVisit.lineItems.first)
            let workItem = try #require(lineItem.sourceWorkItem)
            workItem.setValue(forKey: \WorkItem.invoiceLineItem, to: nil as InvoiceLineItem?)
        case .visitHorsePhotographs:
            let owner = try #require(graph.photograph.visitHorse)
            owner.setValue(forKey: \VisitHorse.photographs, to: [] as [Photograph])
        }
    }
}

enum MissingRelationship: CaseIterable, CustomTestStringConvertible {
    case horseClient
    case horseCurrentBarn
    case appointmentBarn
    case appointmentHorseAppointment
    case appointmentHorseHorse
    case visitAppointment
    case visitBarn
    case visitHorseVisit
    case visitHorseHorse
    case photographVisitHorse
    case workItemService
    case workItemVisitHorse
    case invoiceClient
    case invoiceVisitInvoice
    case invoiceVisitSourceVisit
    case invoiceLineItemInvoiceVisit
    case invoiceLineItemSourceWorkItem

    var testDescription: String { String(describing: self) }

    @MainActor
    func remove(from graph: CompleteGraph) -> DomainGraphViolation {
        switch self {
        case .horseClient:
            graph.horses[0].client = nil
            return .horseMissingClient
        case .horseCurrentBarn:
            graph.horses[0].currentBarn = nil
            return .horseMissingCurrentBarn
        case .appointmentBarn:
            graph.appointments[0].barn = nil
            return .appointmentMissingBarn
        case .appointmentHorseAppointment:
            graph.appointments[0].appointmentHorses[0].appointment = nil
            return .appointmentHorseMissingAppointment
        case .appointmentHorseHorse:
            graph.appointments[0].appointmentHorses[0].horse = nil
            return .appointmentHorseMissingHorse
        case .visitAppointment:
            graph.visits[0].appointment = nil
            return .visitMissingAppointment
        case .visitBarn:
            graph.visits[0].barn = nil
            return .visitMissingBarn
        case .visitHorseVisit:
            graph.visitHorses[0].visit = nil
            return .visitHorseMissingVisit
        case .visitHorseHorse:
            graph.visitHorses[0].horse = nil
            return .visitHorseMissingHorse
        case .photographVisitHorse:
            graph.photograph.visitHorse = nil
            return .photographMissingVisitHorse
        case .workItemService:
            graph.workItems[0].service = nil
            return .workItemMissingService
        case .workItemVisitHorse:
            graph.workItems[0].visitHorse = nil
            return .workItemMissingVisitHorse
        case .invoiceClient:
            graph.invoices[0].setValue(forKey: \Invoice.client, to: nil as Client?)
            return .invoiceMissingClient
        case .invoiceVisitInvoice:
            graph.invoices[0].invoiceVisits[0].setValue(
                forKey: \InvoiceVisit.invoice,
                to: nil as Invoice?
            )
            return .invoiceVisitMissingInvoice
        case .invoiceVisitSourceVisit:
            graph.invoices[0].invoiceVisits[0].setValue(
                forKey: \InvoiceVisit.sourceVisit,
                to: nil as Visit?
            )
            return .invoiceVisitMissingSourceVisit
        case .invoiceLineItemInvoiceVisit:
            graph.invoices[0].invoiceVisits[0].lineItems[0].setValue(
                forKey: \InvoiceLineItem.invoiceVisit,
                to: nil as InvoiceVisit?
            )
            return .invoiceLineItemMissingInvoiceVisit
        case .invoiceLineItemSourceWorkItem:
            graph.invoices[0].invoiceVisits[0].lineItems[0].setValue(
                forKey: \InvoiceLineItem.sourceWorkItem,
                to: nil as WorkItem?
            )
            return .invoiceLineItemMissingSourceWorkItem
        }
    }
}
