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
        exportContext: ExportContext,
        batchSize: Int = 200,
        progress: @escaping @MainActor (ExportSnapshotProgress) -> Void
    ) async throws -> ExportSnapshot {
        guard batchSize > 0 else {
            throw ExportSnapshotError.invalidBatchSize(batchSize)
        }

        let source = try SourceGraph.fetch(in: context)
        try validate(source, in: context)

        let ordered = OrderedGraph(source)
        let totalRecords = ordered.totalRecords
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
                defaultServiceID: optionalID(model.defaultService, in: ids.services)
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
                invoiceLineItemID: optionalID(model.invoiceLineItem, in: ids.invoiceLineItems)
            )
        }
        let invoiceProjection = try await project(
            ordered.invoices,
            entity: .invoice,
            ids: ids.invoices,
            completedRecords: &completedRecords,
            totalRecords: totalRecords,
            batchSize: batchSize,
            progress: progress
        ) { model, id in
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
                    in: ids.clients,
                    entity: .invoice,
                    relationship: "client"
                )
            )
            return (
                record,
                ExportInvoiceDocument(
                    invoiceID: id,
                    relativePath: ExportFormatV1.invoicePDFRelativePath(number: model.number),
                    content: try invoicePDFContent(
                        from: model,
                        localeIdentifier: exportContext.localeIdentifier
                    )
                )
            )
        }
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

        return ExportSnapshot(
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
            invoices: invoiceProjection.map(\.0),
            invoiceVisits: invoiceVisits,
            invoiceLineItems: invoiceLineItems,
            invoiceDocuments: invoiceProjection.map(\.1)
        )
    }

    private static func validate(_ source: SourceGraph, in context: ModelContext) throws {
        try validateRequiredRelationships(source)
        for visitHorse in source.visitHorses where VisitOutcome(rawValue: visitHorse.outcomeRawValue) == nil {
            throw ExportSnapshotError.unsupportedVisitOutcome(visitHorse.outcomeRawValue)
        }
        for invoice in source.invoices {
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
            try DomainGraphValidator.validateAll(in: context)
        } catch let violation as DomainGraphViolation {
            throw ExportSnapshotError.invalidGraph(violation)
        }
    }

    private static func validateRequiredRelationships(_ source: SourceGraph) throws {
        for horse in source.horses {
            guard horse.client != nil else {
                throw ExportSnapshotError.invalidGraph(.horseMissingClient)
            }
            guard horse.currentBarn != nil else {
                throw ExportSnapshotError.invalidGraph(.horseMissingCurrentBarn)
            }
        }
        for appointment in source.appointments where appointment.barn == nil {
            throw ExportSnapshotError.invalidGraph(.appointmentMissingBarn)
        }
        for appointmentHorse in source.appointmentHorses {
            guard appointmentHorse.appointment != nil else {
                throw ExportSnapshotError.invalidGraph(.appointmentHorseMissingAppointment)
            }
            guard appointmentHorse.horse != nil else {
                throw ExportSnapshotError.invalidGraph(.appointmentHorseMissingHorse)
            }
        }
        for visit in source.visits {
            guard visit.appointment != nil else {
                throw ExportSnapshotError.invalidGraph(.visitMissingAppointment)
            }
            guard visit.barn != nil else {
                throw ExportSnapshotError.invalidGraph(.visitMissingBarn)
            }
        }
        for visitHorse in source.visitHorses {
            guard visitHorse.visit != nil else {
                throw ExportSnapshotError.invalidGraph(.visitHorseMissingVisit)
            }
            guard visitHorse.horse != nil else {
                throw ExportSnapshotError.invalidGraph(.visitHorseMissingHorse)
            }
        }
        for photograph in source.photographs where photograph.visitHorse == nil {
            throw ExportSnapshotError.invalidGraph(.photographMissingVisitHorse)
        }
        for workItem in source.workItems {
            guard workItem.service != nil else {
                throw ExportSnapshotError.invalidGraph(.workItemMissingService)
            }
            guard workItem.visitHorse != nil else {
                throw ExportSnapshotError.invalidGraph(.workItemMissingVisitHorse)
            }
        }
        for invoice in source.invoices where invoice.client == nil {
            throw ExportSnapshotError.invalidGraph(.invoiceMissingClient)
        }
        for invoiceVisit in source.invoiceVisits {
            guard invoiceVisit.invoice != nil else {
                throw ExportSnapshotError.invalidGraph(.invoiceVisitMissingInvoice)
            }
            guard invoiceVisit.sourceVisit != nil else {
                throw ExportSnapshotError.invalidGraph(.invoiceVisitMissingSourceVisit)
            }
        }
        for lineItem in source.invoiceLineItems {
            guard lineItem.invoiceVisit != nil else {
                throw ExportSnapshotError.invalidGraph(.invoiceLineItemMissingInvoiceVisit)
            }
            guard lineItem.sourceWorkItem != nil else {
                throw ExportSnapshotError.invalidGraph(.invoiceLineItemMissingSourceWorkItem)
            }
        }
    }

    private static func invoicePDFContent(
        from invoice: Invoice,
        localeIdentifier: String
    ) throws -> InvoicePDFContent {
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
        let visits = InvoiceDomainRules.orderedVisits(invoice.invoiceVisits, locale: locale).map { visit in
            InvoicePDFContent.VisitGroup(
                date: visit.visitDateSnapshot,
                location: visit.serviceLocationNameSnapshot,
                address: visit.serviceLocationAddressSnapshot,
                lineItems: InvoiceDomainRules.orderedLineItems(visit.lineItems, locale: locale).map { lineItem in
                    InvoicePDFContent.LineItem(
                        horseName: lineItem.horseNameSnapshot,
                        serviceName: lineItem.serviceNameSnapshot,
                        amountMinorUnits: lineItem.amountMinorUnits
                    )
                }
            )
        }
        let total: Int64
        do {
            total = try InvoiceDomainRules.checkedTotal(
                visits.flatMap(\.lineItems).map(\.amountMinorUnits)
            )
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
            try Task.checkCancellation()
            await Task.yield()
            try Task.checkCancellation()
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
        in ids: [PersistentIdentifier: ExportRecordID]
    ) -> ExportRecordID? {
        model.flatMap { ids[$0.persistentModelID] }
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

    static func fetch(in context: ModelContext) throws -> SourceGraph {
        SourceGraph(
            businessProfiles: try context.fetch(FetchDescriptor<BusinessProfile>()),
            clients: try context.fetch(FetchDescriptor<Client>()),
            serviceLocations: try context.fetch(FetchDescriptor<Barn>()),
            horses: try context.fetch(FetchDescriptor<Horse>()),
            appointments: try context.fetch(FetchDescriptor<Appointment>()),
            appointmentHorses: try context.fetch(FetchDescriptor<AppointmentHorse>()),
            visits: try context.fetch(FetchDescriptor<Visit>()),
            visitHorses: try context.fetch(FetchDescriptor<VisitHorse>()),
            photographs: try context.fetch(FetchDescriptor<Photograph>()),
            services: try context.fetch(FetchDescriptor<Service>()),
            workItems: try context.fetch(FetchDescriptor<WorkItem>()),
            invoices: try context.fetch(FetchDescriptor<Invoice>()),
            invoiceVisits: try context.fetch(FetchDescriptor<InvoiceVisit>()),
            invoiceLineItems: try context.fetch(FetchDescriptor<InvoiceLineItem>())
        )
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

    init(_ source: SourceGraph) {
        businessProfiles = Self.order(source.businessProfiles) { [$0.name, Self.optional($0.phone), Self.optional($0.email), Self.optional($0.address), Self.optional($0.defaultInvoiceNote), Self.optional($0.defaultAppointmentDurationMinutes), Self.optional($0.defaultInvoiceDueDays), String($0.nextInvoiceNumber)] }
        clients = Self.order(source.clients) { [$0.name, Self.optional($0.phone), Self.optional($0.email), Self.optional($0.notes)] }
        serviceLocations = Self.order(source.serviceLocations) { [$0.name, Self.optional($0.address), Self.optional($0.contactNotes)] }
        horses = Self.order(source.horses) { [$0.name, Self.optional($0.safetyNotes), String($0.appointmentIntervalWeeks), Self.identity($0.client), Self.identity($0.currentBarn), Self.identity($0.defaultService)] }
        appointments = Self.order(source.appointments) { [Self.date($0.startDate), Self.optional($0.notes), Self.optional($0.expectedDurationMinutes), Self.identity($0.barn)] }
        appointmentHorses = Self.order(source.appointmentHorses) { [Self.identity($0.appointment), Self.identity($0.horse)] }
        visits = Self.order(source.visits) { [Self.date($0.startedAt), Self.optionalDate($0.completedAt), $0.serviceLocationNameSnapshot, Self.optional($0.serviceLocationAddressSnapshot), Self.identity($0.appointment), Self.identity($0.barn)] }
        visitHorses = Self.order(source.visitHorses) { [$0.outcomeRawValue, Self.optional($0.workNotes), Self.identity($0.visit), Self.identity($0.horse)] }
        photographs = Self.order(source.photographs) { [$0.id.uuidString.lowercased(), Self.date($0.createdAt), String($0.pixelWidth), String($0.pixelHeight), String($0.byteCount), Self.identity($0.visitHorse)] }
        services = Self.order(source.services) { [$0.name, String($0.defaultAmountMinorUnits), $0.currencyCode, String($0.isArchived)] }
        workItems = Self.order(source.workItems) { [$0.serviceNameSnapshot, String($0.amountMinorUnits), $0.currencyCode, Self.identity($0.service), Self.identity($0.visitHorse), Self.identity($0.invoiceLineItem)] }
        invoices = Self.order(source.invoices) { [String($0.number), Self.date($0.invoiceDate), Self.optionalDate($0.dueDate), Self.optional($0.note), $0.statusRawValue, Self.optionalDate($0.paidAt), $0.clientNameSnapshot, Self.optional($0.clientPhoneSnapshot), Self.optional($0.clientEmailSnapshot), $0.businessNameSnapshot, Self.optional($0.businessPhoneSnapshot), Self.optional($0.businessEmailSnapshot), Self.optional($0.businessAddressSnapshot), $0.currencyCode, Self.identity($0.client)] }
        invoiceVisits = Self.order(source.invoiceVisits) { [Self.date($0.visitDateSnapshot), $0.serviceLocationNameSnapshot, Self.optional($0.serviceLocationAddressSnapshot), Self.identity($0.invoice), Self.identity($0.sourceVisit)] }
        invoiceLineItems = Self.order(source.invoiceLineItems) { [$0.horseNameSnapshot, $0.serviceNameSnapshot, String($0.amountMinorUnits), $0.currencyCode, Self.identity($0.invoiceVisit), Self.identity($0.sourceWorkItem)] }
    }

    var totalRecords: Int {
        businessProfiles.count + clients.count + serviceLocations.count + horses.count
            + appointments.count + appointmentHorses.count + visits.count + visitHorses.count
            + photographs.count + services.count + workItems.count + invoices.count
            + invoiceVisits.count + invoiceLineItems.count
    }

    private static func order<Model: PersistentModel>(
        _ models: [Model],
        keys: (Model) -> [String]
    ) -> [Model] {
        models.sorted { left, right in
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
        while start < models.count {
            try Task.checkCancellation()
            let end = min(start + batchSize, models.count)
            for index in start..<end {
                result[models[index].persistentModelID] = try ExportRecordID(
                    entity: entity,
                    ordinal: index + 1
                )
            }
            try Task.checkCancellation()
            await Task.yield()
            try Task.checkCancellation()
            start = end
        }
        return result
    }
}
