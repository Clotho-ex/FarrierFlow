import Foundation
import SwiftData

nonisolated struct ExportSnapshotProgress: Sendable, Equatable {
    let completedRecords: Int
    let totalRecords: Int
}

@MainActor
enum ExportSnapshotBuilder {
    static func build(
        in context: ModelContext,
        mutationCoordinator: PersistenceMutationCoordinator,
        exportContext: ExportContext,
        batchSize: Int = 200,
        progress: @escaping @MainActor (ExportSnapshotProgress) -> Void
    ) async throws -> ExportSnapshot {
        guard batchSize > 0 else {
            throw ExportSnapshotError.invalidBatchSize(batchSize)
        }
        guard batchSize <= 200 else {
            throw ExportSnapshotError.batchSizeExceedsMaximum(batchSize)
        }

        try Task.checkCancellation()
        let readGuard = try SnapshotReadGuard.begin(using: mutationCoordinator)
        let danglingStartCapture = DanglingRelationshipHints.beginCaptureOperationStart(
            in: context,
            batchSize: batchSize
        )
        let snapshot = try await SnapshotCooperation.withReadGuard(readGuard) {
            try await buildSnapshot(
                in: context,
                danglingStartCapture: danglingStartCapture,
                exportContext: exportContext,
                batchSize: batchSize,
                progress: progress
            )
        }
        try readGuard.validate()
        return snapshot
    }

    private static func buildSnapshot(
        in context: ModelContext,
        danglingStartCapture: DanglingRelationshipHints.OperationStartCapture,
        exportContext: ExportContext,
        batchSize: Int,
        progress: @escaping @MainActor (ExportSnapshotProgress) -> Void
    ) async throws -> ExportSnapshot {
        let danglingStart = try await danglingStartCapture.finish(batchSize: batchSize)
        let danglingRelationships = try await DanglingRelationshipHints.capture(
            in: context,
            operationStart: danglingStart,
            batchSize: batchSize
        )
        let source = try await SourceGraph.fetch(in: context, batchSize: batchSize)
        try await validate(
            source,
            danglingRelationships: danglingRelationships,
            batchSize: batchSize
        )

        let ordered = try await OrderedGraph.make(from: source, batchSize: batchSize)
        let totalRecords = ordered.totalRecords
        try SnapshotCooperation.validateRead()
        progress(.init(completedRecords: 0, totalRecords: totalRecords))
        try Task.checkCancellation()

        let ids = try await IDGraph.make(from: ordered, batchSize: batchSize)
        var completedRecords = 0

        let businessProfiles = try await project(
            ordered.businessProfiles,
            entity: .businessProfile,
            ids: ids.businessProfiles,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            BusinessProfileExportRecord(
                id: id,
                name: model.name,
                phone: model.phone,
                email: model.email,
                address: model.address,
                defaultInvoiceNote: model.defaultInvoiceNote,
                defaultAppointmentDurationMinutes: model.defaultAppointmentDurationMinutes,
                defaultInvoiceDueDays: model.defaultInvoiceDueDays,
                nextInvoiceNumber: model.nextInvoiceNumber
            )
        }
        let clients = try await project(
            ordered.clients,
            entity: .client,
            ids: ids.clients,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            ClientExportRecord(
                id: id,
                name: model.name,
                phone: model.phone,
                email: model.email,
                notes: model.notes
            )
        }
        let serviceLocations = try await project(
            ordered.serviceLocations,
            entity: .serviceLocation,
            ids: ids.serviceLocations,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            ServiceLocationExportRecord(
                id: id,
                name: model.name,
                address: model.address,
                contactNotes: model.contactNotes
            )
        }
        let horses = try await project(
            ordered.horses,
            entity: .horse,
            ids: ids.horses,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            HorseExportRecord(
                id: id,
                name: model.name,
                safetyNotes: model.safetyNotes,
                appointmentIntervalWeeks: model.appointmentIntervalWeeks,
                clientID: try requiredID(
                    model.client,
                    in: ids.clients,
                    entity: .horse,
                    relationship: "client"
                ),
                currentServiceLocationID: try requiredID(
                    model.currentBarn,
                    in: ids.serviceLocations,
                    entity: .horse,
                    relationship: "currentBarn"
                ),
                defaultServiceID: try optionalID(
                    model.defaultService,
                    in: ids.services,
                    entity: .horse,
                    relationship: "defaultService"
                )
            )
        }
        let appointments = try await project(
            ordered.appointments,
            entity: .appointment,
            ids: ids.appointments,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            AppointmentExportRecord(
                id: id,
                startDate: model.startDate,
                notes: model.notes,
                expectedDurationMinutes: model.expectedDurationMinutes,
                serviceLocationID: try requiredID(
                    model.barn,
                    in: ids.serviceLocations,
                    entity: .appointment,
                    relationship: "barn"
                )
            )
        }
        let appointmentHorses = try await project(
            ordered.appointmentHorses,
            entity: .appointmentHorse,
            ids: ids.appointmentHorses,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            AppointmentHorseExportRecord(
                id: id,
                appointmentID: try requiredID(
                    model.appointment,
                    in: ids.appointments,
                    entity: .appointmentHorse,
                    relationship: "appointment"
                ),
                horseID: try requiredID(
                    model.horse,
                    in: ids.horses,
                    entity: .appointmentHorse,
                    relationship: "horse"
                )
            )
        }
        let visits = try await project(
            ordered.visits,
            entity: .visit,
            ids: ids.visits,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            VisitExportRecord(
                id: id,
                startedAt: model.startedAt,
                completedAt: model.completedAt,
                serviceLocationNameSnapshot: model.serviceLocationNameSnapshot,
                serviceLocationAddressSnapshot: model.serviceLocationAddressSnapshot,
                appointmentID: try requiredID(
                    model.appointment,
                    in: ids.appointments,
                    entity: .visit,
                    relationship: "appointment"
                ),
                serviceLocationID: try requiredID(
                    model.barn,
                    in: ids.serviceLocations,
                    entity: .visit,
                    relationship: "barn"
                )
            )
        }
        let visitHorses = try await project(
            ordered.visitHorses,
            entity: .visitHorse,
            ids: ids.visitHorses,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            VisitHorseExportRecord(
                id: id,
                outcomeRawValue: model.outcomeRawValue,
                workNotes: model.workNotes,
                visitID: try requiredID(
                    model.visit,
                    in: ids.visits,
                    entity: .visitHorse,
                    relationship: "visit"
                ),
                horseID: try requiredID(
                    model.horse,
                    in: ids.horses,
                    entity: .visitHorse,
                    relationship: "horse"
                )
            )
        }
        let photographs = try await project(
            ordered.photographs,
            entity: .photograph,
            ids: ids.photographs,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            PhotographExportRecord(
                id: id,
                photographID: model.id,
                createdAt: model.createdAt,
                pixelWidth: model.pixelWidth,
                pixelHeight: model.pixelHeight,
                byteCount: model.byteCount,
                visitHorseID: try requiredID(
                    model.visitHorse,
                    in: ids.visitHorses,
                    entity: .photograph,
                    relationship: "visitHorse"
                )
            )
        }
        let services = try await project(
            ordered.services,
            entity: .service,
            ids: ids.services,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            ServiceExportRecord(
                id: id,
                name: model.name,
                defaultAmountMinorUnits: model.defaultAmountMinorUnits,
                currencyCode: model.currencyCode,
                isArchived: model.isArchived
            )
        }
        let workItems = try await project(
            ordered.workItems,
            entity: .workItem,
            ids: ids.workItems,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            WorkItemExportRecord(
                id: id,
                serviceNameSnapshot: model.serviceNameSnapshot,
                amountMinorUnits: model.amountMinorUnits,
                currencyCode: model.currencyCode,
                serviceID: try requiredID(
                    model.service,
                    in: ids.services,
                    entity: .workItem,
                    relationship: "service"
                ),
                visitHorseID: try requiredID(
                    model.visitHorse,
                    in: ids.visitHorses,
                    entity: .workItem,
                    relationship: "visitHorse"
                ),
                invoiceLineItemID: try optionalID(
                    model.invoiceLineItem,
                    in: ids.invoiceLineItems,
                    entity: .workItem,
                    relationship: "invoiceLineItem"
                )
            )
        }
        let invoiceDocumentGraph = try await InvoiceDocumentGraph.make(
            invoiceVisits: ordered.invoiceVisits,
            invoiceLineItems: ordered.invoiceLineItems,
            batchSize: batchSize
        )
        let invoiceProjection = try await projectInvoices(
            ordered.invoices,
            ids: ids.invoices,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            localeIdentifier: exportContext.localeIdentifier,
            clientIDs: ids.clients,
            documentGraph: invoiceDocumentGraph,
            progress: progress
        )
        let invoiceVisits = try await project(
            ordered.invoiceVisits,
            entity: .invoiceVisit,
            ids: ids.invoiceVisits,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            InvoiceVisitExportRecord(
                id: id,
                visitDateSnapshot: model.visitDateSnapshot,
                serviceLocationNameSnapshot: model.serviceLocationNameSnapshot,
                serviceLocationAddressSnapshot: model.serviceLocationAddressSnapshot,
                invoiceID: try requiredID(
                    model.invoice,
                    in: ids.invoices,
                    entity: .invoiceVisit,
                    relationship: "invoice"
                ),
                sourceVisitID: try requiredID(
                    model.sourceVisit,
                    in: ids.visits,
                    entity: .invoiceVisit,
                    relationship: "sourceVisit"
                )
            )
        }
        let invoiceLineItems = try await project(
            ordered.invoiceLineItems,
            entity: .invoiceLineItem,
            ids: ids.invoiceLineItems,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
            InvoiceLineItemExportRecord(
                id: id,
                horseNameSnapshot: model.horseNameSnapshot,
                serviceNameSnapshot: model.serviceNameSnapshot,
                amountMinorUnits: model.amountMinorUnits,
                currencyCode: model.currencyCode,
                invoiceVisitID: try requiredID(
                    model.invoiceVisit,
                    in: ids.invoiceVisits,
                    entity: .invoiceLineItem,
                    relationship: "invoiceVisit"
                ),
                sourceWorkItemID: try requiredID(
                    model.sourceWorkItem,
                    in: ids.workItems,
                    entity: .invoiceLineItem,
                    relationship: "sourceWorkItem"
                )
            )
        }
        let invoiceRecords = try await SnapshotCooperation.map(
            invoiceProjection,
            batchSize: batchSize
        ) { $0.0 }
        let invoiceDocuments = try await SnapshotCooperation.map(
            invoiceProjection,
            batchSize: batchSize
        ) { $0.1 }

        let snapshot = ExportSnapshot(
            context: exportContext,
            businessProfiles: businessProfiles,
            clients: clients,
            serviceLocations: serviceLocations,
            horses: horses,
            appointments: appointments,
            appointmentHorses: appointmentHorses,
            visits: visits,
            visitHorses: visitHorses,
            photographs: photographs,
            services: services,
            workItems: workItems,
            invoices: invoiceRecords,
            invoiceVisits: invoiceVisits,
            invoiceLineItems: invoiceLineItems,
            invoiceDocuments: invoiceDocuments
        )
        return snapshot
    }

    private static func validate(
        _ source: SourceGraph,
        danglingRelationships: DanglingRelationshipHints,
        batchSize: Int
    ) async throws {
        try await ProjectionRelationshipValidator.validate(
            source,
            danglingRelationships: danglingRelationships,
            batchSize: batchSize
        )
        try await SnapshotCooperation.forEach(source.visitHorses, batchSize: batchSize) { visitHorse in
            guard VisitOutcome(rawValue: visitHorse.outcomeRawValue) != nil else {
                throw ExportSnapshotError.unsupportedVisitOutcome(visitHorse.outcomeRawValue)
            }
        }
        try await SnapshotCooperation.forEach(source.invoices, batchSize: batchSize) { invoice in
            guard InvoiceStatus(rawValue: invoice.statusRawValue) != nil else {
                throw ExportSnapshotError.unsupportedInvoiceStatus(invoice.statusRawValue)
            }
            do {
                _ = try InvoiceDomainRules.validatedStatus(
                    rawValue: invoice.statusRawValue,
                    paidAt: invoice.paidAt
                )
            } catch {
                throw ExportSnapshotError.invalidInvoicePaymentState
            }
        }
        do {
            try await CooperativeDomainGraphValidator.validate(source, batchSize: batchSize)
        } catch let violation as DomainGraphViolation {
            throw ExportSnapshotError.invalidGraph(violation)
        }
    }

    private static func invoicePDFContent(
        from invoice: Invoice,
        invoiceVisits: [InvoiceVisit],
        lineItemsByInvoiceVisit: [PersistentIdentifier: [InvoiceLineItem]],
        localeIdentifier: String,
        batchSize: Int
    ) async throws -> InvoicePDFContent {
        let status: InvoiceStatus
        do {
            status = try InvoiceDomainRules.validatedStatus(
                rawValue: invoice.statusRawValue,
                paidAt: invoice.paidAt
            )
        } catch {
            throw ExportSnapshotError.invalidInvoicePaymentState
        }
        let number: String
        do {
            number = try InvoiceDomainRules.formattedNumber(invoice.number)
        } catch {
            throw ExportSnapshotError.invalidInvoiceNumber(invoice.number)
        }
        let locale = Locale(identifier: localeIdentifier)
        let orderedVisits = try await SnapshotCooperation.sorted(
            invoiceVisits,
            batchSize: batchSize,
            by: { left, right in
                InvoiceDomainRules.orderedVisits([left, right], locale: locale).first === left
            }
        )
        var visits = [InvoicePDFContent.VisitGroup]()
        visits.reserveCapacity(orderedVisits.count)
        try await SnapshotCooperation.forEach(orderedVisits, batchSize: batchSize) { visit in
            let orderedLineItems = try await SnapshotCooperation.sorted(
                lineItemsByInvoiceVisit[visit.persistentModelID, default: []],
                batchSize: batchSize,
                by: { left, right in
                    InvoiceDomainRules.orderedLineItems([left, right], locale: locale).first === left
                }
            )
            let lineItems = try await SnapshotCooperation.map(
                orderedLineItems,
                batchSize: batchSize
            ) { lineItem in
                InvoicePDFContent.LineItem(
                    horseName: lineItem.horseNameSnapshot,
                    serviceName: lineItem.serviceNameSnapshot,
                    amountMinorUnits: lineItem.amountMinorUnits
                )
            }
            visits.append(InvoicePDFContent.VisitGroup(
                date: visit.visitDateSnapshot,
                location: visit.serviceLocationNameSnapshot,
                address: visit.serviceLocationAddressSnapshot,
                lineItems: lineItems
            ))
        }
        let total: Int64
        do {
            total = try await checkedInvoiceTotal(visits, batchSize: batchSize)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ExportSnapshotError.invalidInvoiceTotal
        }
        return InvoicePDFContent(
            number: number,
            invoiceDate: invoice.invoiceDate,
            dueDate: invoice.dueDate,
            status: status,
            paidAt: invoice.paidAt,
            businessName: invoice.businessNameSnapshot,
            businessPhone: invoice.businessPhoneSnapshot,
            businessEmail: invoice.businessEmailSnapshot,
            businessAddress: invoice.businessAddressSnapshot,
            clientName: invoice.clientNameSnapshot,
            clientPhone: invoice.clientPhoneSnapshot,
            clientEmail: invoice.clientEmailSnapshot,
            visits: visits,
            totalMinorUnits: total,
            note: invoice.note
        )
    }

    private static func checkedInvoiceTotal(
        _ visits: [InvoicePDFContent.VisitGroup],
        batchSize: Int
    ) async throws -> Int64 {
        var total: Int64 = 0
        try await SnapshotCooperation.forEach(visits, batchSize: batchSize) { visit in
            try await SnapshotCooperation.forEach(visit.lineItems, batchSize: batchSize) { lineItem in
                total = try InvoiceDomainRules.checkedTotal([total, lineItem.amountMinorUnits])
            }
        }
        return total
    }

    private static func projectInvoices(
        _ source: [Invoice],
        ids: [PersistentIdentifier: ExportRecordID],
        completedRecords: inout Int,
        totalRecords: Int,
        batchSize: Int,
        localeIdentifier: String,
        clientIDs: [PersistentIdentifier: ExportRecordID],
        documentGraph: InvoiceDocumentGraph,
        progress: @escaping @MainActor (ExportSnapshotProgress) -> Void
    ) async throws -> [(InvoiceExportRecord, ExportInvoiceDocument)] {
        var output = [(InvoiceExportRecord, ExportInvoiceDocument)]()
        output.reserveCapacity(source.count)
        var start = 0
        while start < source.count {
            try await SnapshotCooperation.checkpoint()
            let end = min(start + batchSize, source.count)
            for model in source[start..<end] {
                guard let id = ids[model.persistentModelID] else {
                    throw ExportSnapshotError.missingProjectedRelationship(
                        entity: .invoice,
                        relationship: "exportID"
                    )
                }
                let record = InvoiceExportRecord(
                    id: id,
                    number: model.number,
                    invoiceDate: model.invoiceDate,
                    dueDate: model.dueDate,
                    note: model.note,
                    statusRawValue: model.statusRawValue,
                    paidAt: model.paidAt,
                    clientNameSnapshot: model.clientNameSnapshot,
                    clientPhoneSnapshot: model.clientPhoneSnapshot,
                    clientEmailSnapshot: model.clientEmailSnapshot,
                    businessNameSnapshot: model.businessNameSnapshot,
                    businessPhoneSnapshot: model.businessPhoneSnapshot,
                    businessEmailSnapshot: model.businessEmailSnapshot,
                    businessAddressSnapshot: model.businessAddressSnapshot,
                    currencyCode: model.currencyCode,
                    clientID: try requiredID(
                        model.client,
                        in: clientIDs,
                        entity: .invoice,
                        relationship: "client"
                    )
                )
                let content = try await invoicePDFContent(
                    from: model,
                    invoiceVisits: documentGraph.visitsByInvoice[
                        model.persistentModelID,
                        default: []
                    ],
                    lineItemsByInvoiceVisit: documentGraph.lineItemsByInvoiceVisit,
                    localeIdentifier: localeIdentifier,
                    batchSize: batchSize
                )
                output.append((
                    record,
                    ExportInvoiceDocument(
                        invoiceID: id,
                        relativePath: ExportFormatV1.invoicePDFRelativePath(number: model.number),
                        content: content
                    )
                ))
            }
            completedRecords += end - start
            progress(.init(completedRecords: completedRecords, totalRecords: totalRecords))
            try await SnapshotCooperation.checkpoint()
            start = end
        }
        return output
    }

    private static func project<Source: PersistentModel, Output>(
        _ source: [Source],
        entity: ExportEntity,
        ids: [PersistentIdentifier: ExportRecordID],
        completedRecords: inout Int,
        totalRecords: Int,
        batchSize: Int,
        progress: @escaping @MainActor (ExportSnapshotProgress) -> Void,
        transform: (Source, ExportRecordID) throws -> Output
    ) async throws -> [Output] {
        var output = [Output]()
        output.reserveCapacity(source.count)
        var start = 0
        while start < source.count {
            try Task.checkCancellation()
            let end = min(start + batchSize, source.count)
            for model in source[start..<end] {
                guard let id = ids[model.persistentModelID] else {
                    throw ExportSnapshotError.missingProjectedRelationship(
                        entity: entity,
                        relationship: "exportID"
                    )
                }
                output.append(try transform(model, id))
            }
            completedRecords += end - start
            progress(.init(completedRecords: completedRecords, totalRecords: totalRecords))
            try await SnapshotCooperation.checkpoint()
            start = end
        }
        return output
    }

    private static func requiredID<Model: PersistentModel>(
        _ model: Model?,
        in ids: [PersistentIdentifier: ExportRecordID],
        entity: ExportEntity,
        relationship: String
    ) throws -> ExportRecordID {
        guard let model, let id = ids[model.persistentModelID] else {
            throw ExportSnapshotError.missingProjectedRelationship(
                entity: entity,
                relationship: relationship
            )
        }
        return id
    }

    private static func optionalID<Model: PersistentModel>(
        _ model: Model?,
        in ids: [PersistentIdentifier: ExportRecordID],
        entity: ExportEntity,
        relationship: String
    ) throws -> ExportRecordID? {
        guard let model else { return nil }
        guard let id = ids[model.persistentModelID] else {
            throw ExportSnapshotError.missingProjectedRelationship(
                entity: entity,
                relationship: relationship
            )
        }
        return id
    }
}

@MainActor
private struct InvoiceDocumentGraph {
    let visitsByInvoice: [PersistentIdentifier: [InvoiceVisit]]
    let lineItemsByInvoiceVisit: [PersistentIdentifier: [InvoiceLineItem]]

    static func make(
        invoiceVisits: [InvoiceVisit],
        invoiceLineItems: [InvoiceLineItem],
        batchSize: Int
    ) async throws -> InvoiceDocumentGraph {
        var visitsByInvoice = [PersistentIdentifier: [InvoiceVisit]]()
        try await SnapshotCooperation.forEach(invoiceVisits, batchSize: batchSize) { visit in
            guard let invoice = visit.invoice else {
                throw ExportSnapshotError.invalidGraph(.invoiceVisitMissingInvoice)
            }
            visitsByInvoice[invoice.persistentModelID, default: []].append(visit)
        }

        var lineItemsByInvoiceVisit = [PersistentIdentifier: [InvoiceLineItem]]()
        try await SnapshotCooperation.forEach(invoiceLineItems, batchSize: batchSize) { lineItem in
            guard let invoiceVisit = lineItem.invoiceVisit else {
                throw ExportSnapshotError.invalidGraph(.invoiceLineItemMissingInvoiceVisit)
            }
            lineItemsByInvoiceVisit[invoiceVisit.persistentModelID, default: []].append(lineItem)
        }

        return InvoiceDocumentGraph(
            visitsByInvoice: visitsByInvoice,
            lineItemsByInvoiceVisit: lineItemsByInvoiceVisit
        )
    }
}

@MainActor
private struct SourceGraph {
    let businessProfiles: [BusinessProfile]
    let clients: [Client]
    let serviceLocations: [Barn]
    let horses: [Horse]
    let appointments: [Appointment]
    let appointmentHorses: [AppointmentHorse]
    let visits: [Visit]
    let visitHorses: [VisitHorse]
    let photographs: [Photograph]
    let services: [Service]
    let workItems: [WorkItem]
    let invoices: [Invoice]
    let invoiceVisits: [InvoiceVisit]
    let invoiceLineItems: [InvoiceLineItem]

    static func fetch(in context: ModelContext, batchSize: Int) async throws -> SourceGraph {
        let businessProfiles = try await fetch(BusinessProfile.self, in: context, batchSize: batchSize)
        let clients = try await fetch(Client.self, in: context, batchSize: batchSize)
        let serviceLocations = try await fetch(Barn.self, in: context, batchSize: batchSize)
        let horses = try await fetch(Horse.self, in: context, batchSize: batchSize)
        let appointments = try await fetch(Appointment.self, in: context, batchSize: batchSize)
        let appointmentHorses = try await fetch(AppointmentHorse.self, in: context, batchSize: batchSize)
        let visits = try await fetch(Visit.self, in: context, batchSize: batchSize)
        let visitHorses = try await fetch(VisitHorse.self, in: context, batchSize: batchSize)
        let photographs = try await fetch(Photograph.self, in: context, batchSize: batchSize)
        let services = try await fetch(Service.self, in: context, batchSize: batchSize)
        let workItems = try await fetch(WorkItem.self, in: context, batchSize: batchSize)
        let invoices = try await fetch(Invoice.self, in: context, batchSize: batchSize)
        let invoiceVisits = try await fetch(InvoiceVisit.self, in: context, batchSize: batchSize)
        let invoiceLineItems = try await fetch(InvoiceLineItem.self, in: context, batchSize: batchSize)

        return SourceGraph(
            businessProfiles: businessProfiles,
            clients: clients,
            serviceLocations: serviceLocations,
            horses: horses,
            appointments: appointments,
            appointmentHorses: appointmentHorses,
            visits: visits,
            visitHorses: visitHorses,
            photographs: photographs,
            services: services,
            workItems: workItems,
            invoices: invoices,
            invoiceVisits: invoiceVisits,
            invoiceLineItems: invoiceLineItems
        )
    }

    private static func fetch<Model: PersistentModel>(
        _ type: Model.Type,
        in context: ModelContext,
        batchSize: Int
    ) async throws -> [Model] {
        try await SnapshotCooperation.checkpoint()
        let identifiers = try context.fetchIdentifiers(FetchDescriptor<Model>())
        try await SnapshotCooperation.checkpoint()

        var models = [Model]()
        models.reserveCapacity(identifiers.count)
        var start = 0
        while start < identifiers.count {
            let end = min(start + batchSize, identifiers.count)
            for identifier in identifiers[start..<end] {
                guard let model = context.model(for: identifier) as? Model,
                      !model.isDeleted else {
                    throw ExportSnapshotError.sourceDataChanged
                }
                models.append(model)
            }
            try await SnapshotCooperation.checkpoint()
            start = end
        }
        return models
    }
}

@MainActor
private struct OrderedGraph {
    let businessProfiles: [BusinessProfile]
    let clients: [Client]
    let serviceLocations: [Barn]
    let horses: [Horse]
    let appointments: [Appointment]
    let appointmentHorses: [AppointmentHorse]
    let visits: [Visit]
    let visitHorses: [VisitHorse]
    let photographs: [Photograph]
    let services: [Service]
    let workItems: [WorkItem]
    let invoices: [Invoice]
    let invoiceVisits: [InvoiceVisit]
    let invoiceLineItems: [InvoiceLineItem]

    static func make(from source: SourceGraph, batchSize: Int) async throws -> OrderedGraph {
        OrderedGraph(
            businessProfiles: try await order(source.businessProfiles, batchSize: batchSize) { [$0.name, optional($0.phone), optional($0.email), optional($0.address), optional($0.defaultInvoiceNote), optional($0.defaultAppointmentDurationMinutes), optional($0.defaultInvoiceDueDays), String($0.nextInvoiceNumber)] },
            clients: try await order(source.clients, batchSize: batchSize) { [$0.name, optional($0.phone), optional($0.email), optional($0.notes)] },
            serviceLocations: try await order(source.serviceLocations, batchSize: batchSize) { [$0.name, optional($0.address), optional($0.contactNotes)] },
            horses: try await order(source.horses, batchSize: batchSize) { [$0.name, optional($0.safetyNotes), String($0.appointmentIntervalWeeks), identity($0.client), identity($0.currentBarn), identity($0.defaultService)] },
            appointments: try await order(source.appointments, batchSize: batchSize) { [date($0.startDate), optional($0.notes), optional($0.expectedDurationMinutes), identity($0.barn)] },
            appointmentHorses: try await order(source.appointmentHorses, batchSize: batchSize) { [identity($0.appointment), identity($0.horse)] },
            visits: try await order(source.visits, batchSize: batchSize) { [date($0.startedAt), optionalDate($0.completedAt), $0.serviceLocationNameSnapshot, optional($0.serviceLocationAddressSnapshot), identity($0.appointment), identity($0.barn)] },
            visitHorses: try await order(source.visitHorses, batchSize: batchSize) { [$0.outcomeRawValue, optional($0.workNotes), identity($0.visit), identity($0.horse)] },
            photographs: try await order(source.photographs, batchSize: batchSize) { [$0.id.uuidString.lowercased(), date($0.createdAt), String($0.pixelWidth), String($0.pixelHeight), String($0.byteCount), identity($0.visitHorse)] },
            services: try await order(source.services, batchSize: batchSize) { [$0.name, String($0.defaultAmountMinorUnits), $0.currencyCode, String($0.isArchived)] },
            workItems: try await order(source.workItems, batchSize: batchSize) { [$0.serviceNameSnapshot, String($0.amountMinorUnits), $0.currencyCode, identity($0.service), identity($0.visitHorse), identity($0.invoiceLineItem)] },
            invoices: try await order(source.invoices, batchSize: batchSize) { [String($0.number), date($0.invoiceDate), optionalDate($0.dueDate), optional($0.note), $0.statusRawValue, optionalDate($0.paidAt), $0.clientNameSnapshot, optional($0.clientPhoneSnapshot), optional($0.clientEmailSnapshot), $0.businessNameSnapshot, optional($0.businessPhoneSnapshot), optional($0.businessEmailSnapshot), optional($0.businessAddressSnapshot), $0.currencyCode, identity($0.client)] },
            invoiceVisits: try await order(source.invoiceVisits, batchSize: batchSize) { [date($0.visitDateSnapshot), $0.serviceLocationNameSnapshot, optional($0.serviceLocationAddressSnapshot), identity($0.invoice), identity($0.sourceVisit)] },
            invoiceLineItems: try await order(source.invoiceLineItems, batchSize: batchSize) { [$0.horseNameSnapshot, $0.serviceNameSnapshot, String($0.amountMinorUnits), $0.currencyCode, identity($0.invoiceVisit), identity($0.sourceWorkItem)] }
        )
    }

    var totalRecords: Int {
        businessProfiles.count + clients.count + serviceLocations.count + horses.count
            + appointments.count + appointmentHorses.count + visits.count + visitHorses.count
            + photographs.count + services.count + workItems.count + invoices.count
            + invoiceVisits.count + invoiceLineItems.count
    }

    private static func order<Model: PersistentModel>(
        _ models: [Model],
        batchSize: Int,
        keys: (Model) -> [String]
    ) async throws -> [Model] {
        try await SnapshotCooperation.sorted(models, batchSize: batchSize) { left, right in
            let leftKeys = keys(left)
            let rightKeys = keys(right)
            for (leftKey, rightKey) in zip(leftKeys, rightKeys) where leftKey != rightKey {
                return leftKey < rightKey
            }
            return identity(left) < identity(right)
        }
    }

    private static func optional(_ value: String?) -> String { value.map { "1:\($0)" } ?? "0:" }
    private static func optional<T: BinaryInteger>(_ value: T?) -> String { value.map { "1:\($0)" } ?? "0:" }
    private static func date(_ value: Date) -> String { String(value.timeIntervalSinceReferenceDate.bitPattern) }
    private static func optionalDate(_ value: Date?) -> String { value.map { "1:\(date($0))" } ?? "0:" }
    private static func identity<Model: PersistentModel>(_ model: Model?) -> String {
        model.map { String(describing: $0.persistentModelID) } ?? ""
    }
}

@MainActor
private struct IDGraph {
    let businessProfiles: [PersistentIdentifier: ExportRecordID]
    let clients: [PersistentIdentifier: ExportRecordID]
    let serviceLocations: [PersistentIdentifier: ExportRecordID]
    let horses: [PersistentIdentifier: ExportRecordID]
    let appointments: [PersistentIdentifier: ExportRecordID]
    let appointmentHorses: [PersistentIdentifier: ExportRecordID]
    let visits: [PersistentIdentifier: ExportRecordID]
    let visitHorses: [PersistentIdentifier: ExportRecordID]
    let photographs: [PersistentIdentifier: ExportRecordID]
    let services: [PersistentIdentifier: ExportRecordID]
    let workItems: [PersistentIdentifier: ExportRecordID]
    let invoices: [PersistentIdentifier: ExportRecordID]
    let invoiceVisits: [PersistentIdentifier: ExportRecordID]
    let invoiceLineItems: [PersistentIdentifier: ExportRecordID]

    static func make(from graph: OrderedGraph, batchSize: Int) async throws -> IDGraph {
        IDGraph(
            businessProfiles: try await ids(for: graph.businessProfiles, entity: .businessProfile, batchSize: batchSize),
            clients: try await ids(for: graph.clients, entity: .client, batchSize: batchSize),
            serviceLocations: try await ids(for: graph.serviceLocations, entity: .serviceLocation, batchSize: batchSize),
            horses: try await ids(for: graph.horses, entity: .horse, batchSize: batchSize),
            appointments: try await ids(for: graph.appointments, entity: .appointment, batchSize: batchSize),
            appointmentHorses: try await ids(for: graph.appointmentHorses, entity: .appointmentHorse, batchSize: batchSize),
            visits: try await ids(for: graph.visits, entity: .visit, batchSize: batchSize),
            visitHorses: try await ids(for: graph.visitHorses, entity: .visitHorse, batchSize: batchSize),
            photographs: try await ids(for: graph.photographs, entity: .photograph, batchSize: batchSize),
            services: try await ids(for: graph.services, entity: .service, batchSize: batchSize),
            workItems: try await ids(for: graph.workItems, entity: .workItem, batchSize: batchSize),
            invoices: try await ids(for: graph.invoices, entity: .invoice, batchSize: batchSize),
            invoiceVisits: try await ids(for: graph.invoiceVisits, entity: .invoiceVisit, batchSize: batchSize),
            invoiceLineItems: try await ids(for: graph.invoiceLineItems, entity: .invoiceLineItem, batchSize: batchSize)
        )
    }

    private static func ids<Model: PersistentModel>(
        for models: [Model],
        entity: ExportEntity,
        batchSize: Int
    ) async throws -> [PersistentIdentifier: ExportRecordID] {
        var result = [PersistentIdentifier: ExportRecordID]()
        result.reserveCapacity(models.count)
        var start = 0
        try await SnapshotCooperation.checkpoint()
        while start < models.count {
            let end = min(start + batchSize, models.count)
            for index in start..<end {
                result[models[index].persistentModelID] = try ExportRecordID(
                    entity: entity,
                    ordinal: index + 1
                )
            }
            try await SnapshotCooperation.checkpoint()
            start = end
        }
        return result
    }
}

@MainActor
private struct SnapshotReadGuard: Sendable {
    private let coordinator: PersistenceMutationCoordinator
    private let generation: PersistenceMutationCoordinator.ReadGeneration

    static func begin(
        using coordinator: PersistenceMutationCoordinator
    ) throws -> SnapshotReadGuard {
        do {
            return SnapshotReadGuard(
                coordinator: coordinator,
                generation: try coordinator.beginRead()
            )
        } catch {
            throw ExportSnapshotError.sourceDataChanged
        }
    }

    func validate() throws {
        do {
            try coordinator.validate(generation)
        } catch {
            throw ExportSnapshotError.sourceDataChanged
        }
    }
}

@MainActor
private enum SnapshotCooperation {
    @TaskLocal private static var readGuard: SnapshotReadGuard?

    static func withReadGuard<Output>(
        _ guardValue: SnapshotReadGuard,
        operation: () async throws -> Output
    ) async rethrows -> Output {
        try await $readGuard.withValue(guardValue, operation: operation)
    }

    static func validateRead() throws {
        guard let readGuard else {
            preconditionFailure("Snapshot read guard must be installed")
        }
        try readGuard.validate()
    }

    static func checkpoint() async throws {
        try Task.checkCancellation()
        await Task.yield()
        try Task.checkCancellation()
        try validateRead()
    }

    static func forEach<Element>(
        _ elements: [Element],
        batchSize: Int,
        _ body: (Element) async throws -> Void
    ) async throws {
        try await checkpoint()
        var start = 0
        while start < elements.count {
            let end = min(start + batchSize, elements.count)
            for element in elements[start..<end] {
                try await body(element)
            }
            try await checkpoint()
            start = end
        }
    }

    static func map<Element, Output>(
        _ elements: [Element],
        batchSize: Int,
        _ transform: (Element) async throws -> Output
    ) async throws -> [Output] {
        var output = [Output]()
        output.reserveCapacity(elements.count)
        try await forEach(elements, batchSize: batchSize) { element in
            output.append(try await transform(element))
        }
        return output
    }

    static func sorted<Element>(
        _ elements: [Element],
        batchSize: Int,
        by areInIncreasingOrder: (Element, Element) -> Bool
    ) async throws -> [Element] {
        var runs = [[Element]]()
        var start = 0
        try await checkpoint()
        while start < elements.count {
            let end = min(start + batchSize, elements.count)
            runs.append(elements[start..<end].sorted(by: areInIncreasingOrder))
            try await checkpoint()
            start = end
        }
        while runs.count > 1 {
            var mergedRuns = [[Element]]()
            mergedRuns.reserveCapacity((runs.count + 1) / 2)
            var index = 0
            while index < runs.count {
                guard index + 1 < runs.count else {
                    mergedRuns.append(runs[index])
                    index += 1
                    continue
                }
                mergedRuns.append(
                    try await merge(
                        runs[index],
                        runs[index + 1],
                        batchSize: batchSize,
                        by: areInIncreasingOrder
                    )
                )
                index += 2
            }
            runs = mergedRuns
            try await checkpoint()
        }
        try await checkpoint()
        return runs.first ?? []
    }

    private static func merge<Element>(
        _ left: [Element],
        _ right: [Element],
        batchSize: Int,
        by areInIncreasingOrder: (Element, Element) -> Bool
    ) async throws -> [Element] {
        var output = [Element]()
        output.reserveCapacity(left.count + right.count)
        var leftIndex = 0
        var rightIndex = 0
        var sinceCheckpoint = 0
        while leftIndex < left.count || rightIndex < right.count {
            if rightIndex == right.count
                || (leftIndex < left.count
                    && !areInIncreasingOrder(right[rightIndex], left[leftIndex])) {
                output.append(left[leftIndex])
                leftIndex += 1
            } else {
                output.append(right[rightIndex])
                rightIndex += 1
            }
            sinceCheckpoint += 1
            if sinceCheckpoint == batchSize {
                try await checkpoint()
                sinceCheckpoint = 0
            }
        }
        if sinceCheckpoint > 0 {
            try await checkpoint()
        }
        return output
    }
}

@MainActor
private struct DanglingRelationshipHints {
    struct Key: Hashable {
        let entity: ExportEntity
        let relationship: String
    }

    enum CurrentTarget {
        case none
        case identifier(PersistentIdentifier)
    }

    struct CurrentRelationshipTargets {
        struct Entry {
            let key: Key
            let ownerID: PersistentIdentifier
            let target: CurrentTarget
        }

        private var targets = [Key: [PersistentIdentifier: CurrentTarget]]()
        var entries = [Entry]()

        mutating func captureBatch(
            _ changedModels: [any PersistentModel],
            startingAt start: Int,
            batchSize: Int
        ) -> Int {
            let end = min(start + batchSize, changedModels.count)
            for model in changedModels[start..<end] {
                switch model {
                case let horse as Horse:
                    record(horse.client, owner: horse, entity: .horse, relationship: "client")
                    record(horse.currentBarn, owner: horse, entity: .horse, relationship: "currentBarn")
                    record(horse.defaultService, owner: horse, entity: .horse, relationship: "defaultService")
                case let appointment as Appointment:
                    record(appointment.barn, owner: appointment, entity: .appointment, relationship: "barn")
                case let membership as AppointmentHorse:
                    record(membership.appointment, owner: membership, entity: .appointmentHorse, relationship: "appointment")
                    record(membership.horse, owner: membership, entity: .appointmentHorse, relationship: "horse")
                case let visit as Visit:
                    record(visit.appointment, owner: visit, entity: .visit, relationship: "appointment")
                    record(visit.barn, owner: visit, entity: .visit, relationship: "barn")
                case let membership as VisitHorse:
                    record(membership.visit, owner: membership, entity: .visitHorse, relationship: "visit")
                    record(membership.horse, owner: membership, entity: .visitHorse, relationship: "horse")
                case let photograph as Photograph:
                    record(photograph.visitHorse, owner: photograph, entity: .photograph, relationship: "visitHorse")
                case let workItem as WorkItem:
                    record(workItem.visitHorse, owner: workItem, entity: .workItem, relationship: "visitHorse")
                    record(workItem.service, owner: workItem, entity: .workItem, relationship: "service")
                    record(workItem.invoiceLineItem, owner: workItem, entity: .workItem, relationship: "invoiceLineItem")
                case let invoice as Invoice:
                    record(invoice.client, owner: invoice, entity: .invoice, relationship: "client")
                case let invoiceVisit as InvoiceVisit:
                    record(invoiceVisit.invoice, owner: invoiceVisit, entity: .invoiceVisit, relationship: "invoice")
                    record(invoiceVisit.sourceVisit, owner: invoiceVisit, entity: .invoiceVisit, relationship: "sourceVisit")
                case let lineItem as InvoiceLineItem:
                    record(lineItem.invoiceVisit, owner: lineItem, entity: .invoiceLineItem, relationship: "invoiceVisit")
                    record(lineItem.sourceWorkItem, owner: lineItem, entity: .invoiceLineItem, relationship: "sourceWorkItem")
                default:
                    break
                }
            }
            return end
        }

        func target(
            ownerID: PersistentIdentifier,
            entity: ExportEntity,
            relationship: String
        ) -> CurrentTarget? {
            targets[Key(entity: entity, relationship: relationship)]?[ownerID]
        }

        private mutating func record<Owner: PersistentModel, Target: PersistentModel>(
            _ target: Target?,
            owner: Owner,
            entity: ExportEntity,
            relationship: String
        ) {
            let key = Key(entity: entity, relationship: relationship)
            let currentTarget = target.map { .identifier($0.persistentModelID) } ?? CurrentTarget.none
            targets[key, default: [:]][owner.persistentModelID] = currentTarget
            entries.append(Entry(
                key: key,
                ownerID: owner.persistentModelID,
                target: currentTarget
            ))
        }
    }

    private var ownerIDs = [Key: Set<PersistentIdentifier>]()

    struct OperationStart {
        let deletedModels: [any PersistentModel]
        let currentRelationships: CurrentRelationshipTargets
    }

    struct OperationStartCapture {
        let deletedModels: [any PersistentModel]
        let changedModels: [any PersistentModel]
        var currentRelationships: CurrentRelationshipTargets
        var nextChangedIndex: Int

        func finish(batchSize: Int) async throws -> OperationStart {
            var capture = self
            while capture.nextChangedIndex < capture.changedModels.count {
                try await SnapshotCooperation.checkpoint()
                capture.nextChangedIndex = capture.currentRelationships.captureBatch(
                    capture.changedModels,
                    startingAt: capture.nextChangedIndex,
                    batchSize: batchSize
                )
            }
            try await SnapshotCooperation.checkpoint()
            return OperationStart(
                deletedModels: capture.deletedModels,
                currentRelationships: capture.currentRelationships
            )
        }
    }

    static func beginCaptureOperationStart(
        in context: ModelContext,
        batchSize: Int
    ) -> OperationStartCapture {
        let deletedModels = context.deletedModelsArray
        let changedModels = context.changedModelsArray
        var currentRelationships = CurrentRelationshipTargets()
        let nextChangedIndex = currentRelationships.captureBatch(
            changedModels,
            startingAt: 0,
            batchSize: batchSize
        )
        return OperationStartCapture(
            deletedModels: deletedModels,
            changedModels: changedModels,
            currentRelationships: currentRelationships,
            nextChangedIndex: nextChangedIndex
        )
    }

    static func capture(
        in context: ModelContext,
        operationStart: OperationStart,
        batchSize: Int
    ) async throws -> DanglingRelationshipHints {
        let deletedModels = operationStart.deletedModels
        let currentRelationships = operationStart.currentRelationships
        var result = DanglingRelationshipHints()
        var deletedTargetIDs = Set<PersistentIdentifier>()
        try await SnapshotCooperation.forEach(deletedModels, batchSize: batchSize) { model in
            deletedTargetIDs.insert(model.persistentModelID)
        }
        try await SnapshotCooperation.forEach(
            currentRelationships.entries,
            batchSize: batchSize
        ) { entry in
            guard case let .identifier(targetID) = entry.target,
                  deletedTargetIDs.contains(targetID) else {
                return
            }
            result.ownerIDs[entry.key, default: []].insert(entry.ownerID)
        }
        try await SnapshotCooperation.forEach(deletedModels, batchSize: batchSize) { deletedModel in
            switch deletedModel {
            case let client as Client:
                let targetID = client.persistentModelID
                try await result.register(
                    FetchDescriptor<Horse>(predicate: #Predicate {
                        $0.client?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .horse,
                    relationship: "client",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
                try await result.register(
                    FetchDescriptor<Invoice>(predicate: #Predicate {
                        $0.client?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .invoice,
                    relationship: "client",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
            case let barn as Barn:
                let targetID = barn.persistentModelID
                try await result.register(
                    FetchDescriptor<Horse>(predicate: #Predicate {
                        $0.currentBarn?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .horse,
                    relationship: "currentBarn",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
                try await result.register(
                    FetchDescriptor<Appointment>(predicate: #Predicate {
                        $0.barn?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .appointment,
                    relationship: "barn",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
                try await result.register(
                    FetchDescriptor<Visit>(predicate: #Predicate {
                        $0.barn?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .visit,
                    relationship: "barn",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
            case let service as Service:
                let targetID = service.persistentModelID
                try await result.register(
                    FetchDescriptor<Horse>(predicate: #Predicate {
                        $0.defaultService?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .horse,
                    relationship: "defaultService",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
                try await result.register(
                    FetchDescriptor<WorkItem>(predicate: #Predicate {
                        $0.service?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .workItem,
                    relationship: "service",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
            case let appointment as Appointment:
                let targetID = appointment.persistentModelID
                try await result.register(
                    FetchDescriptor<AppointmentHorse>(predicate: #Predicate {
                        $0.appointment?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .appointmentHorse,
                    relationship: "appointment",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
                try await result.register(
                    FetchDescriptor<Visit>(predicate: #Predicate {
                        $0.appointment?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .visit,
                    relationship: "appointment",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
            case let horse as Horse:
                let targetID = horse.persistentModelID
                try await result.register(
                    FetchDescriptor<AppointmentHorse>(predicate: #Predicate {
                        $0.horse?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .appointmentHorse,
                    relationship: "horse",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
                try await result.register(
                    FetchDescriptor<VisitHorse>(predicate: #Predicate {
                        $0.horse?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .visitHorse,
                    relationship: "horse",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
            case let visit as Visit:
                let targetID = visit.persistentModelID
                try await result.register(
                    FetchDescriptor<VisitHorse>(predicate: #Predicate {
                        $0.visit?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .visitHorse,
                    relationship: "visit",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
                try await result.register(
                    FetchDescriptor<InvoiceVisit>(predicate: #Predicate {
                        $0.sourceVisit?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .invoiceVisit,
                    relationship: "sourceVisit",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
            case let visitHorse as VisitHorse:
                let targetID = visitHorse.persistentModelID
                try await result.register(
                    FetchDescriptor<Photograph>(predicate: #Predicate {
                        $0.visitHorse?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .photograph,
                    relationship: "visitHorse",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
                try await result.register(
                    FetchDescriptor<WorkItem>(predicate: #Predicate {
                        $0.visitHorse?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .workItem,
                    relationship: "visitHorse",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
            case let workItem as WorkItem:
                let targetID = workItem.persistentModelID
                try await result.register(
                    FetchDescriptor<InvoiceLineItem>(predicate: #Predicate {
                        $0.sourceWorkItem?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .invoiceLineItem,
                    relationship: "sourceWorkItem",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
            case let invoice as Invoice:
                let targetID = invoice.persistentModelID
                try await result.register(
                    FetchDescriptor<InvoiceVisit>(predicate: #Predicate {
                        $0.invoice?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .invoiceVisit,
                    relationship: "invoice",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
            case let invoiceVisit as InvoiceVisit:
                let targetID = invoiceVisit.persistentModelID
                try await result.register(
                    FetchDescriptor<InvoiceLineItem>(predicate: #Predicate {
                        $0.invoiceVisit?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .invoiceLineItem,
                    relationship: "invoiceVisit",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
            case let lineItem as InvoiceLineItem:
                let targetID = lineItem.persistentModelID
                try await result.register(
                    FetchDescriptor<WorkItem>(predicate: #Predicate {
                        $0.invoiceLineItem?.persistentModelID == targetID
                    }),
                    in: context,
                    targetID: targetID,
                    entity: .workItem,
                    relationship: "invoiceLineItem",
                    batchSize: batchSize,
                    currentRelationships: currentRelationships
                )
            default:
                break
            }
        }
        return result
    }

    func validate(
        ownerIDs: [ExportEntity: Set<PersistentIdentifier>],
        batchSize: Int
    ) async throws {
        for (key, hintedOwnerIDs) in self.ownerIDs {
            guard let fetchedOwnerIDs = ownerIDs[key.entity] else { continue }
            var checked = 0
            for ownerID in hintedOwnerIDs {
                if fetchedOwnerIDs.contains(ownerID) {
                    throw ExportSnapshotError.missingProjectedRelationship(
                        entity: key.entity,
                        relationship: key.relationship
                    )
                }
                checked += 1
                if checked == batchSize {
                    try await SnapshotCooperation.checkpoint()
                    checked = 0
                }
            }
            if checked > 0 {
                try await SnapshotCooperation.checkpoint()
            }
        }
    }

    private mutating func register<Model: PersistentModel>(
        _ baseDescriptor: FetchDescriptor<Model>,
        in context: ModelContext,
        targetID: PersistentIdentifier,
        entity: ExportEntity,
        relationship: String,
        batchSize: Int,
        currentRelationships: CurrentRelationshipTargets
    ) async throws {
        // Query the last saved graph because SwiftData normalizes deleted targets out of
        // the deleting context's fetch results. Changed owners were snapshotted before
        // this saved-graph query, so reassignment and optional clearing can be reconciled
        // without traversing a target's potentially unbounded inverse collection.
        let persistedContext = ModelContext(context.container)
        persistedContext.autosaveEnabled = false
        try await SnapshotCooperation.checkpoint()
        let savedOwnerIDs = try persistedContext.fetchIdentifiers(baseDescriptor)
        try await SnapshotCooperation.checkpoint()
        var start = 0
        while start < savedOwnerIDs.count {
            let end = min(start + batchSize, savedOwnerIDs.count)
            for ownerID in savedOwnerIDs[start..<end] {
                guard let owner = context.model(for: ownerID) as? Model,
                      !owner.isDeleted else {
                    continue
                }
                if let currentTarget = currentRelationships.target(
                    ownerID: ownerID,
                    entity: entity,
                    relationship: relationship
                ) {
                    guard case let .identifier(currentTargetID) = currentTarget,
                          currentTargetID == targetID else {
                        continue
                    }
                }
                ownerIDs[Key(entity: entity, relationship: relationship), default: []].insert(ownerID)
            }
            try await SnapshotCooperation.checkpoint()
            start = end
        }
    }
}

@MainActor
private enum ProjectionRelationshipValidator {
    static func validate(
        _ source: SourceGraph,
        danglingRelationships: DanglingRelationshipHints,
        batchSize: Int
    ) async throws {
        let clients = try await identities(source.clients, batchSize: batchSize)
        let serviceLocations = try await identities(source.serviceLocations, batchSize: batchSize)
        let horses = try await identities(source.horses, batchSize: batchSize)
        let appointments = try await identities(source.appointments, batchSize: batchSize)
        let visits = try await identities(source.visits, batchSize: batchSize)
        let visitHorses = try await identities(source.visitHorses, batchSize: batchSize)
        let services = try await identities(source.services, batchSize: batchSize)
        let workItems = try await identities(source.workItems, batchSize: batchSize)
        let invoices = try await identities(source.invoices, batchSize: batchSize)
        let invoiceVisits = try await identities(source.invoiceVisits, batchSize: batchSize)
        let invoiceLineItems = try await identities(source.invoiceLineItems, batchSize: batchSize)
        try await danglingRelationships.validate(
            ownerIDs: [
                .horse: horses,
                .appointment: appointments,
                .appointmentHorse: try await identities(source.appointmentHorses, batchSize: batchSize),
                .visit: visits,
                .visitHorse: visitHorses,
                .photograph: try await identities(source.photographs, batchSize: batchSize),
                .workItem: workItems,
                .invoice: invoices,
                .invoiceVisit: invoiceVisits,
                .invoiceLineItem: invoiceLineItems,
            ],
            batchSize: batchSize
        )

        try await SnapshotCooperation.forEach(source.horses, batchSize: batchSize) { horse in
            try required(
                horse.client,
                in: clients,
                missing: .horseMissingClient,
                entity: .horse,
                relationship: "client"
            )
            try required(
                horse.currentBarn,
                in: serviceLocations,
                missing: .horseMissingCurrentBarn,
                entity: .horse,
                relationship: "currentBarn"
            )
            try optional(
                horse.defaultService,
                in: services,
                entity: .horse,
                relationship: "defaultService"
            )
        }
        try await SnapshotCooperation.forEach(source.appointments, batchSize: batchSize) { appointment in
            try required(
                appointment.barn,
                in: serviceLocations,
                missing: .appointmentMissingBarn,
                entity: .appointment,
                relationship: "barn"
            )
        }
        try await SnapshotCooperation.forEach(source.appointmentHorses, batchSize: batchSize) { membership in
            try required(
                membership.appointment,
                in: appointments,
                missing: .appointmentHorseMissingAppointment,
                entity: .appointmentHorse,
                relationship: "appointment"
            )
            try required(
                membership.horse,
                in: horses,
                missing: .appointmentHorseMissingHorse,
                entity: .appointmentHorse,
                relationship: "horse"
            )
        }
        try await SnapshotCooperation.forEach(source.visits, batchSize: batchSize) { visit in
            try required(
                visit.appointment,
                in: appointments,
                missing: .visitMissingAppointment,
                entity: .visit,
                relationship: "appointment"
            )
            try required(
                visit.barn,
                in: serviceLocations,
                missing: .visitMissingBarn,
                entity: .visit,
                relationship: "barn"
            )
        }
        try await SnapshotCooperation.forEach(source.visitHorses, batchSize: batchSize) { membership in
            try required(
                membership.visit,
                in: visits,
                missing: .visitHorseMissingVisit,
                entity: .visitHorse,
                relationship: "visit"
            )
            try required(
                membership.horse,
                in: horses,
                missing: .visitHorseMissingHorse,
                entity: .visitHorse,
                relationship: "horse"
            )
        }
        try await SnapshotCooperation.forEach(source.photographs, batchSize: batchSize) { photograph in
            try required(
                photograph.visitHorse,
                in: visitHorses,
                missing: .photographMissingVisitHorse,
                entity: .photograph,
                relationship: "visitHorse"
            )
        }
        try await SnapshotCooperation.forEach(source.workItems, batchSize: batchSize) { workItem in
            try required(
                workItem.service,
                in: services,
                missing: .workItemMissingService,
                entity: .workItem,
                relationship: "service"
            )
            try required(
                workItem.visitHorse,
                in: visitHorses,
                missing: .workItemMissingVisitHorse,
                entity: .workItem,
                relationship: "visitHorse"
            )
            try optional(
                workItem.invoiceLineItem,
                in: invoiceLineItems,
                entity: .workItem,
                relationship: "invoiceLineItem"
            )
        }
        try await SnapshotCooperation.forEach(source.invoices, batchSize: batchSize) { invoice in
            try required(
                invoice.client,
                in: clients,
                missing: .invoiceMissingClient,
                entity: .invoice,
                relationship: "client"
            )
        }
        try await SnapshotCooperation.forEach(source.invoiceVisits, batchSize: batchSize) { invoiceVisit in
            try required(
                invoiceVisit.invoice,
                in: invoices,
                missing: .invoiceVisitMissingInvoice,
                entity: .invoiceVisit,
                relationship: "invoice"
            )
            try required(
                invoiceVisit.sourceVisit,
                in: visits,
                missing: .invoiceVisitMissingSourceVisit,
                entity: .invoiceVisit,
                relationship: "sourceVisit"
            )
        }
        try await SnapshotCooperation.forEach(source.invoiceLineItems, batchSize: batchSize) { lineItem in
            try required(
                lineItem.invoiceVisit,
                in: invoiceVisits,
                missing: .invoiceLineItemMissingInvoiceVisit,
                entity: .invoiceLineItem,
                relationship: "invoiceVisit"
            )
            try required(
                lineItem.sourceWorkItem,
                in: workItems,
                missing: .invoiceLineItemMissingSourceWorkItem,
                entity: .invoiceLineItem,
                relationship: "sourceWorkItem"
            )
        }
    }

    private static func identities<Model: PersistentModel>(
        _ models: [Model],
        batchSize: Int
    ) async throws -> Set<PersistentIdentifier> {
        var result = Set<PersistentIdentifier>()
        result.reserveCapacity(models.count)
        try await SnapshotCooperation.forEach(models, batchSize: batchSize) {
            result.insert($0.persistentModelID)
        }
        return result
    }

    private static func required<Model: PersistentModel>(
        _ model: Model?,
        in identities: Set<PersistentIdentifier>,
        missing: DomainGraphViolation,
        entity: ExportEntity,
        relationship: String
    ) throws {
        guard let model else {
            throw ExportSnapshotError.invalidGraph(missing)
        }
        guard identities.contains(model.persistentModelID) else {
            throw ExportSnapshotError.missingProjectedRelationship(
                entity: entity,
                relationship: relationship
            )
        }
    }

    private static func optional<Model: PersistentModel>(
        _ model: Model?,
        in identities: Set<PersistentIdentifier>,
        entity: ExportEntity,
        relationship: String
    ) throws {
        guard let model else { return }
        guard identities.contains(model.persistentModelID) else {
            throw ExportSnapshotError.missingProjectedRelationship(
                entity: entity,
                relationship: relationship
            )
        }
    }
}

// Mirrors the canonical persisted-graph rules while keeping each record scan cooperative.
@MainActor
private enum CooperativeDomainGraphValidator {
    static func validate(_ source: SourceGraph, batchSize: Int) async throws {
        guard source.businessProfiles.count <= 1 else {
            throw DomainGraphViolation.duplicateBusinessProfile
        }
        if let profile = source.businessProfiles.first {
            try validate(profile)
        } else if !source.invoices.isEmpty {
            throw DomainGraphViolation.businessProfileMissing
        }

        var invoiceNumbers = Set<Int64>()
        var greatestInvoiceNumber: Int64?
        try await SnapshotCooperation.forEach(source.invoices, batchSize: batchSize) { invoice in
            guard invoice.number > 0 else {
                throw DomainGraphViolation.invoiceNumberInvalid
            }
            guard invoiceNumbers.insert(invoice.number).inserted else {
                throw DomainGraphViolation.duplicateInvoiceNumber
            }
            greatestInvoiceNumber = max(greatestInvoiceNumber ?? invoice.number, invoice.number)
        }
        if let profile = source.businessProfiles.first,
           let greatestInvoiceNumber,
           profile.nextInvoiceNumber <= greatestInvoiceNumber {
            throw DomainGraphViolation.businessProfileSequenceInvalid
        }

        // SwiftData derives the declared service, client, invoice, visit, visit-horse,
        // and invoice-visit inverse collections from their children's to-one links.
        // Complete fetched-child indexes therefore express those same canonical
        // memberships and cardinalities without faulting any owner to-many collection.
        try await SnapshotCooperation.forEach(source.services, batchSize: batchSize) { service in
            try validate(service)
        }
        try await SnapshotCooperation.forEach(source.horses, batchSize: batchSize) { horse in
            try validate(horse)
        }
        var workItemsByVisitHorse = [PersistentIdentifier: [WorkItem]]()
        try await SnapshotCooperation.forEach(source.workItems, batchSize: batchSize) { workItem in
            try validate(workItem)
            guard let visitHorse = workItem.visitHorse else {
                throw DomainGraphViolation.workItemMissingVisitHorse
            }
            workItemsByVisitHorse[visitHorse.persistentModelID, default: []].append(workItem)
        }

        var lineItemsByInvoiceVisit = [PersistentIdentifier: [InvoiceLineItem]]()
        var billedWorkItemIDs = Set<PersistentIdentifier>()
        try await SnapshotCooperation.forEach(source.invoiceLineItems, batchSize: batchSize) { lineItem in
            try await validate(lineItem, batchSize: batchSize)
            guard let invoiceVisit = lineItem.invoiceVisit else {
                throw DomainGraphViolation.invoiceLineItemMissingInvoiceVisit
            }
            guard let sourceWorkItem = lineItem.sourceWorkItem,
                  billedWorkItemIDs.insert(sourceWorkItem.persistentModelID).inserted else {
                throw DomainGraphViolation.duplicateInvoiceLineItemSource
            }
            lineItemsByInvoiceVisit[invoiceVisit.persistentModelID, default: []].append(lineItem)
        }

        var visitsByInvoice = [PersistentIdentifier: [InvoiceVisit]]()
        var invoiceVisitsBySourceVisit = [PersistentIdentifier: [InvoiceVisit]]()
        try await SnapshotCooperation.forEach(source.invoiceVisits, batchSize: batchSize) { invoiceVisit in
            try await validate(
                invoiceVisit,
                lineItems: lineItemsByInvoiceVisit[invoiceVisit.persistentModelID, default: []],
                batchSize: batchSize
            )
            guard let invoice = invoiceVisit.invoice else {
                throw DomainGraphViolation.invoiceVisitMissingInvoice
            }
            visitsByInvoice[invoice.persistentModelID, default: []].append(invoiceVisit)
            guard let sourceVisit = invoiceVisit.sourceVisit else {
                throw DomainGraphViolation.invoiceVisitMissingSourceVisit
            }
            invoiceVisitsBySourceVisit[sourceVisit.persistentModelID, default: []].append(invoiceVisit)
        }
        try await SnapshotCooperation.forEach(source.invoices, batchSize: batchSize) { invoice in
            try await validate(
                invoice,
                visits: visitsByInvoice[invoice.persistentModelID, default: []],
                lineItemsByInvoiceVisit: lineItemsByInvoiceVisit,
                batchSize: batchSize
            )
        }

        var appointmentMemberships = [PersistentIdentifier: [AppointmentHorse]]()
        try await SnapshotCooperation.forEach(source.appointmentHorses, batchSize: batchSize) { membership in
            guard let appointment = membership.appointment else {
                throw DomainGraphViolation.appointmentHorseMissingAppointment
            }
            guard membership.horse != nil else {
                throw DomainGraphViolation.appointmentHorseMissingHorse
            }
            appointmentMemberships[appointment.persistentModelID, default: []].append(membership)
        }

        var visitMemberships = [PersistentIdentifier: [VisitHorse]]()
        try await SnapshotCooperation.forEach(source.visitHorses, batchSize: batchSize) { membership in
            guard let visit = membership.visit else {
                throw DomainGraphViolation.visitHorseMissingVisit
            }
            guard membership.horse != nil else {
                throw DomainGraphViolation.visitHorseMissingHorse
            }
            visitMemberships[visit.persistentModelID, default: []].append(membership)
        }

        var photographIDs = Set<UUID>()
        try await SnapshotCooperation.forEach(source.photographs, batchSize: batchSize) { photograph in
            try validate(photograph)
            guard photographIDs.insert(photograph.id).inserted else {
                throw DomainGraphViolation.duplicatePhotographID
            }
        }

        var visitsByAppointment = [PersistentIdentifier: [Visit]]()
        try await SnapshotCooperation.forEach(source.visits, batchSize: batchSize) { visit in
            if let appointment = visit.appointment {
                visitsByAppointment[appointment.persistentModelID, default: []].append(visit)
            }
            try await validate(
                visit,
                memberships: visitMemberships[visit.persistentModelID, default: []],
                workItemsByVisitHorse: workItemsByVisitHorse,
                invoiceVisits: invoiceVisitsBySourceVisit[visit.persistentModelID, default: []],
                appointmentMemberships: appointmentMemberships,
                batchSize: batchSize
            )
        }
        try await SnapshotCooperation.forEach(source.appointments, batchSize: batchSize) { appointment in
            try await validate(
                appointment,
                memberships: appointmentMemberships[appointment.persistentModelID, default: []],
                visits: visitsByAppointment[appointment.persistentModelID, default: []],
                batchSize: batchSize
            )
        }
    }

    private static func validate(_ profile: BusinessProfile) throws {
        guard TextNormalization.required(profile.name) == profile.name else {
            throw DomainGraphViolation.businessProfileNameNotNormalized
        }
        guard isNormalized(profile.phone), isNormalized(profile.email),
              isNormalized(profile.address), isNormalized(profile.defaultInvoiceNote) else {
            throw DomainGraphViolation.businessProfileOptionalTextNotNormalized
        }
        guard profile.nextInvoiceNumber > 0 else {
            throw DomainGraphViolation.businessProfileSequenceInvalid
        }
        guard profile.defaultAppointmentDurationMinutes.map({ $0 > 0 }) ?? true,
              profile.defaultInvoiceDueDays.map({ $0 > 0 }) ?? true else {
            throw DomainGraphViolation.businessProfileDefaultInvalid
        }
    }

    private static func validate(_ service: Service) throws {
        guard TextNormalization.required(service.name) == service.name else {
            throw DomainGraphViolation.serviceNameNotNormalized
        }
        guard service.defaultAmountMinorUnits >= 0 else {
            throw DomainGraphViolation.serviceAmountNegative
        }
        guard service.currencyCode == "USD" else {
            throw DomainGraphViolation.serviceCurrencyInvalid
        }
    }

    private static func validate(_ horse: Horse) throws {
        guard horse.client != nil else { throw DomainGraphViolation.horseMissingClient }
        guard horse.currentBarn != nil else { throw DomainGraphViolation.horseMissingCurrentBarn }
        if let service = horse.defaultService {
            guard !service.isArchived else {
                throw DomainGraphViolation.horseDefaultServiceArchived
            }
        }
    }

    private static func validate(_ workItem: WorkItem) throws {
        guard workItem.service != nil else {
            throw DomainGraphViolation.workItemMissingService
        }
        guard workItem.visitHorse != nil else {
            throw DomainGraphViolation.workItemMissingVisitHorse
        }
        guard TextNormalization.required(workItem.serviceNameSnapshot) == workItem.serviceNameSnapshot else {
            throw DomainGraphViolation.workItemServiceNameSnapshotNotNormalized
        }
        guard workItem.amountMinorUnits >= 0 else {
            throw DomainGraphViolation.workItemAmountNegative
        }
        guard workItem.currencyCode == "USD" else {
            throw DomainGraphViolation.workItemCurrencyInvalid
        }
        if let lineItem = workItem.invoiceLineItem,
           lineItem.sourceWorkItem !== workItem {
            throw DomainGraphViolation.invoiceLineItemWorkItemInverseMismatch
        }
    }

    private static func validate(_ lineItem: InvoiceLineItem, batchSize _: Int) async throws {
        guard let invoiceVisit = lineItem.invoiceVisit else {
            throw DomainGraphViolation.invoiceLineItemMissingInvoiceVisit
        }
        guard let sourceWorkItem = lineItem.sourceWorkItem else {
            throw DomainGraphViolation.invoiceLineItemMissingSourceWorkItem
        }
        guard sourceWorkItem.invoiceLineItem === lineItem else {
            throw DomainGraphViolation.invoiceLineItemWorkItemInverseMismatch
        }
        guard let sourceVisitHorse = sourceWorkItem.visitHorse,
              let sourceVisit = sourceVisitHorse.visit,
              invoiceVisit.sourceVisit === sourceVisit else {
            throw DomainGraphViolation.invoiceLineItemSourceVisitMismatch
        }
        guard TextNormalization.required(lineItem.horseNameSnapshot) == lineItem.horseNameSnapshot,
              TextNormalization.required(lineItem.serviceNameSnapshot) == lineItem.serviceNameSnapshot else {
            throw DomainGraphViolation.invoiceLineItemSnapshotNotNormalized
        }
        guard lineItem.amountMinorUnits >= 0 else {
            throw DomainGraphViolation.invoiceLineItemAmountNegative
        }
        guard lineItem.currencyCode == "USD" else {
            throw DomainGraphViolation.invoiceLineItemCurrencyInvalid
        }
        guard let invoiceClient = invoiceVisit.invoice?.client,
              sourceVisitHorse.horse?.client === invoiceClient else {
            throw DomainGraphViolation.invoiceLineItemClientMismatch
        }
    }

    private static func validate(
        _ invoiceVisit: InvoiceVisit,
        lineItems: [InvoiceLineItem],
        batchSize: Int
    ) async throws {
        guard invoiceVisit.invoice != nil else {
            throw DomainGraphViolation.invoiceVisitMissingInvoice
        }
        guard invoiceVisit.sourceVisit != nil else {
            throw DomainGraphViolation.invoiceVisitMissingSourceVisit
        }
        guard TextNormalization.required(invoiceVisit.serviceLocationNameSnapshot)
                == invoiceVisit.serviceLocationNameSnapshot,
              isNormalized(invoiceVisit.serviceLocationAddressSnapshot) else {
            throw DomainGraphViolation.invoiceVisitSnapshotNotNormalized
        }
        guard !lineItems.isEmpty else {
            throw DomainGraphViolation.invoiceVisitHasNoLineItem
        }
        try await SnapshotCooperation.forEach(lineItems, batchSize: batchSize) {
            guard $0.invoiceVisit === invoiceVisit else {
                throw DomainGraphViolation.invoiceLineItemVisitInverseMismatch
            }
        }
    }

    private static func validate(
        _ invoice: Invoice,
        visits: [InvoiceVisit],
        lineItemsByInvoiceVisit: [PersistentIdentifier: [InvoiceLineItem]],
        batchSize: Int
    ) async throws {
        guard invoice.client != nil else {
            throw DomainGraphViolation.invoiceMissingClient
        }
        guard TextNormalization.required(invoice.clientNameSnapshot) == invoice.clientNameSnapshot,
              TextNormalization.required(invoice.businessNameSnapshot) == invoice.businessNameSnapshot,
              isNormalized(invoice.clientPhoneSnapshot), isNormalized(invoice.clientEmailSnapshot),
              isNormalized(invoice.businessPhoneSnapshot), isNormalized(invoice.businessEmailSnapshot),
              isNormalized(invoice.businessAddressSnapshot), isNormalized(invoice.note) else {
            throw DomainGraphViolation.invoiceSnapshotNotNormalized
        }
        guard invoice.currencyCode == "USD" else {
            throw DomainGraphViolation.invoiceCurrencyInvalid
        }
        do {
            _ = try InvoiceDomainRules.validatedStatus(
                rawValue: invoice.statusRawValue,
                paidAt: invoice.paidAt
            )
        } catch {
            throw DomainGraphViolation.invoiceStatusInvalid
        }
        guard !visits.isEmpty else { throw DomainGraphViolation.invoiceHasNoVisit }
        var sourceVisitIDs = Set<PersistentIdentifier>()
        var total: Int64 = 0
        try await SnapshotCooperation.forEach(visits, batchSize: batchSize) { visit in
            guard visit.invoice === invoice else {
                throw DomainGraphViolation.invoiceVisitInvoiceInverseMismatch
            }
            guard let sourceVisit = visit.sourceVisit else {
                throw DomainGraphViolation.invoiceVisitMissingSourceVisit
            }
            guard sourceVisitIDs.insert(sourceVisit.persistentModelID).inserted else {
                throw DomainGraphViolation.duplicateInvoiceVisitSource
            }
            try await SnapshotCooperation.forEach(
                lineItemsByInvoiceVisit[visit.persistentModelID, default: []],
                batchSize: batchSize
            ) { lineItem in
                do {
                    total = try CheckedMoneyTotal.sum([total, lineItem.amountMinorUnits])
                } catch {
                    throw DomainGraphViolation.invoiceTotalOverflow
                }
            }
        }
    }

    private static func validate(_ photograph: Photograph) throws {
        guard photograph.visitHorse != nil else {
            throw DomainGraphViolation.photographMissingVisitHorse
        }
        guard photograph.pixelWidth > 0, photograph.pixelHeight > 0,
              max(photograph.pixelWidth, photograph.pixelHeight) <= 2_560 else {
            throw DomainGraphViolation.invalidPhotographDimensions
        }
        guard photograph.byteCount > 0 else {
            throw DomainGraphViolation.invalidPhotographByteCount
        }
    }

    private static func validate(
        _ visit: Visit,
        memberships: [VisitHorse],
        workItemsByVisitHorse: [PersistentIdentifier: [WorkItem]],
        invoiceVisits: [InvoiceVisit],
        appointmentMemberships: [PersistentIdentifier: [AppointmentHorse]],
        batchSize: Int
    ) async throws {
        guard let appointment = visit.appointment else { throw DomainGraphViolation.visitMissingAppointment }
        guard let barn = visit.barn else { throw DomainGraphViolation.visitMissingBarn }
        guard appointment.visit === visit, appointment.barn === barn else {
            throw DomainGraphViolation.appointmentVisitMismatch
        }
        guard TextNormalization.required(visit.serviceLocationNameSnapshot) != nil else {
            throw DomainGraphViolation.visitLocationNameMissing
        }
        guard !memberships.isEmpty else { throw DomainGraphViolation.visitHasNoHorse }
        try await SnapshotCooperation.forEach(invoiceVisits, batchSize: batchSize) {
            guard $0.sourceVisit === visit else {
                throw DomainGraphViolation.invoiceVisitSourceInverseMismatch
            }
        }

        var appointmentHorseIDs = Set<PersistentIdentifier>()
        try await SnapshotCooperation.forEach(
            appointmentMemberships[appointment.persistentModelID, default: []],
            batchSize: batchSize
        ) { membership in
            guard let horse = membership.horse else {
                throw DomainGraphViolation.appointmentHorseMissingHorse
            }
            appointmentHorseIDs.insert(horse.persistentModelID)
        }

        var visitHorseIDs = Set<PersistentIdentifier>()
        var hasPendingHorse = false
        var hasServicedHorse = false
        var total: Int64 = 0
        try await SnapshotCooperation.forEach(memberships, batchSize: batchSize) { membership in
            guard let horse = membership.horse else {
                throw DomainGraphViolation.visitHorseMissingHorse
            }
            guard visitHorseIDs.insert(horse.persistentModelID).inserted else {
                throw DomainGraphViolation.duplicateVisitHorseMembership
            }
            guard let outcome = VisitOutcome(rawValue: membership.outcomeRawValue) else {
                throw DomainGraphViolation.visitMembershipMismatch
            }
            if TextNormalization.optional(membership.workNotes ?? "") != nil,
               outcome != .serviced {
                throw DomainGraphViolation.workNotesRequireServicedOutcome
            }
            let workItems = workItemsByVisitHorse[membership.persistentModelID, default: []]
            if outcome == .notServiced, !workItems.isEmpty {
                throw DomainGraphViolation.notServicedVisitHorseHasWorkItems
            }
            var serviceIDs = Set<PersistentIdentifier>()
            try await SnapshotCooperation.forEach(workItems, batchSize: batchSize) { workItem in
                guard let service = workItem.service else {
                    throw DomainGraphViolation.workItemMissingService
                }
                guard serviceIDs.insert(service.persistentModelID).inserted else {
                    throw DomainGraphViolation.duplicateWorkItemService
                }
                do {
                    total = try CheckedMoneyTotal.sum([total, workItem.amountMinorUnits])
                } catch {
                    throw DomainGraphViolation.workItemTotalOverflow
                }
            }
            hasPendingHorse = hasPendingHorse || outcome == .pending
            hasServicedHorse = hasServicedHorse || outcome == .serviced
            if visit.completedAt != nil, outcome == .serviced, workItems.isEmpty {
                throw DomainGraphViolation.completedServicedVisitHorseHasNoWorkItems
            }
        }
        guard visitHorseIDs == appointmentHorseIDs else {
            throw DomainGraphViolation.visitMembershipMismatch
        }
        if let completedAt = visit.completedAt {
            guard completedAt >= visit.startedAt else {
                throw DomainGraphViolation.completionPredatesStart
            }
            guard !hasPendingHorse else {
                throw DomainGraphViolation.completedVisitHasPendingHorse
            }
            guard hasServicedHorse else {
                throw DomainGraphViolation.completedVisitHasNoServicedHorse
            }
        }
    }

    private static func validate(
        _ appointment: Appointment,
        memberships: [AppointmentHorse],
        visits: [Visit],
        batchSize: Int
    ) async throws {
        guard let barn = appointment.barn else { throw DomainGraphViolation.appointmentMissingBarn }
        guard !memberships.isEmpty else { throw DomainGraphViolation.appointmentHasNoValidHorse }
        guard visits.count <= 1 else { throw DomainGraphViolation.appointmentVisitMismatch }
        if let visit = appointment.visit {
            guard visit.appointment === appointment, visits.first === visit else {
                throw DomainGraphViolation.appointmentVisitMismatch
            }
        } else if !visits.isEmpty {
            throw DomainGraphViolation.appointmentVisitMismatch
        }
        var horseIDs = Set<PersistentIdentifier>()
        try await SnapshotCooperation.forEach(memberships, batchSize: batchSize) { membership in
            guard let horse = membership.horse else {
                throw DomainGraphViolation.appointmentHorseMissingHorse
            }
            if appointment.visit?.completedAt == nil, horse.currentBarn !== barn {
                throw DomainGraphViolation.horseOutsideAppointmentBarn
            }
            guard horseIDs.insert(horse.persistentModelID).inserted else {
                throw DomainGraphViolation.duplicateHorseMembership
            }
        }
    }

    private static func isNormalized(_ value: String?) -> Bool {
        guard let value else { return true }
        return TextNormalization.optional(value) == value
    }
}
