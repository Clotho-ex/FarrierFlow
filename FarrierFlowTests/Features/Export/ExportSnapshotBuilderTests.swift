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
}

@MainActor
private final class ExportSnapshotTaskHolder {
    var task: Task<ExportSnapshot, Error>?
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
