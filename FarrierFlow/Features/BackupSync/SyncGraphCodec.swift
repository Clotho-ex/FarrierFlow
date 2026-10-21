import Foundation
import SwiftData

nonisolated enum SyncGraphError: Error, Equatable {
    case unsavedChanges
    case invalidField(String)
    case missingRelationship(String)
    case immutableHistoryChanged
    case invoiceNumberCollision
}

@MainActor
enum SyncGraphCodec {
    static func capture(in context: ModelContext) throws -> [SyncRecord] {
        guard !context.hasChanges else { throw SyncGraphError.unsavedChanges }
        try DomainGraphValidator.validateAll(in: context)
        return try captureValidated(in: context)
    }

    private static func captureValidated(in context: ModelContext) throws -> [SyncRecord] {
        var result: [SyncRecord] = []
        for model in try context.fetch(FetchDescriptor<BusinessProfile>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .businessProfile, fields: [
                "name": text(model.name),
                "phone": text(model.phone),
                "email": text(model.email),
                "address": text(model.address),
                "defaultInvoiceNote": text(model.defaultInvoiceNote),
                "defaultAppointmentDurationMinutes": integer(model.defaultAppointmentDurationMinutes),
                "defaultInvoiceDueDays": integer(model.defaultInvoiceDueDays),
                "nextInvoiceNumber": .integer(model.nextInvoiceNumber),
                "currencyCode": text(model.currencyCode),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<Client>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .client, fields: [
                "name": text(model.name),
                "phone": text(model.phone),
                "email": text(model.email),
                "notes": text(model.notes),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<Barn>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .barn, fields: [
                "name": text(model.name),
                "address": text(model.address),
                "contactNotes": text(model.contactNotes),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<Service>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .service, fields: [
                "name": text(model.name),
                "defaultAmountMinorUnits": .integer(model.defaultAmountMinorUnits),
                "currencyCode": text(model.currencyCode),
                "isArchived": .boolean(model.isArchived),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<Horse>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .horse, fields: [
                "name": text(model.name),
                "safetyNotes": text(model.safetyNotes),
                "appointmentIntervalWeeks": integer(model.appointmentIntervalWeeks),
                "client": try reference(model.client),
                "currentBarn": try reference(model.currentBarn),
                "defaultService": try reference(model.defaultService),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<Appointment>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .appointment, fields: [
                "startDate": try date(model.startDate),
                "notes": text(model.notes),
                "expectedDurationMinutes": integer(model.expectedDurationMinutes),
                "barn": try reference(model.barn),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<AppointmentHorse>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .appointmentHorse, fields: [
                "appointment": try reference(model.appointment),
                "horse": try reference(model.horse),
                "plannedService": try reference(model.plannedService),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<Visit>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .visit, fields: [
                "startedAt": try date(model.startedAt),
                "completedAt": try date(model.completedAt),
                "serviceLocationNameSnapshot": text(model.serviceLocationNameSnapshot),
                "serviceLocationAddressSnapshot": text(model.serviceLocationAddressSnapshot),
                "appointment": try reference(model.appointment),
                "barn": try reference(model.barn),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<VisitHorse>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .visitHorse, fields: [
                "outcomeRawValue": text(model.outcomeRawValue),
                "workNotes": text(model.workNotes),
                "visit": try reference(model.visit),
                "horse": try reference(model.horse),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<Photograph>()) {
            result.append(try photographRecord(model))
        }
        for model in try context.fetch(FetchDescriptor<WorkItem>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .workItem, fields: [
                "serviceNameSnapshot": text(model.serviceNameSnapshot),
                "amountMinorUnits": .integer(model.amountMinorUnits),
                "currencyCode": text(model.currencyCode),
                "billingHoldID": text(model.billingHoldID?.uuidString.lowercased()),
                "service": try reference(model.service),
                "visitHorse": try reference(model.visitHorse),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<Invoice>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .invoice, fields: [
                "number": .integer(model.number),
                "invoiceDate": try date(model.invoiceDate),
                "dueDate": try date(model.dueDate),
                "note": text(model.note),
                "statusRawValue": text(model.statusRawValue),
                "clientNameSnapshot": text(model.clientNameSnapshot),
                "clientPhoneSnapshot": text(model.clientPhoneSnapshot),
                "clientEmailSnapshot": text(model.clientEmailSnapshot),
                "businessNameSnapshot": text(model.businessNameSnapshot),
                "businessPhoneSnapshot": text(model.businessPhoneSnapshot),
                "businessEmailSnapshot": text(model.businessEmailSnapshot),
                "businessAddressSnapshot": text(model.businessAddressSnapshot),
                "currencyCode": text(model.currencyCode),
                "client": try reference(model.client),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<InvoiceVisit>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .invoiceVisit, fields: [
                "visitDateSnapshot": try date(model.visitDateSnapshot),
                "serviceLocationNameSnapshot": text(model.serviceLocationNameSnapshot),
                "serviceLocationAddressSnapshot": text(model.serviceLocationAddressSnapshot),
                "invoice": try reference(model.invoice),
                "sourceVisit": try reference(model.sourceVisit),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<InvoiceLineItem>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .invoiceLineItem, fields: [
                "horseNameSnapshot": text(model.horseNameSnapshot),
                "serviceNameSnapshot": text(model.serviceNameSnapshot),
                "amountMinorUnits": .integer(model.amountMinorUnits),
                "currencyCode": text(model.currencyCode),
                "invoiceVisit": try reference(model.invoiceVisit),
                "sourceWorkItem": try reference(model.sourceWorkItem),
            ]))
        }
        for model in try context.fetch(FetchDescriptor<Payment>()) {
            guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
            result.append(SyncRecord(id: id, kind: .payment, fields: [
                "amountMinorUnits": .integer(model.amountMinorUnits),
                "currencyCode": text(model.currencyCode),
                "receivedAt": try date(model.receivedAt),
                "methodRawValue": text(model.methodRawValue),
                "sourceRawValue": text(model.sourceRawValue),
                "otherDescription": text(model.otherDescription),
                "reference": text(model.reference),
                "note": text(model.note),
                "invoice": try reference(model.invoice),
            ]))
        }
        _ = try SyncJournal.index(result)
        return result.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    static func photographRecord(_ model: Photograph) throws -> SyncRecord {
        SyncRecord(id: model.id, kind: .photograph, fields: [
            "createdAt": try date(model.createdAt),
            "pixelWidth": integer(model.pixelWidth),
            "pixelHeight": integer(model.pixelHeight),
            "byteCount": .integer(model.byteCount),
            "visitHorse": try reference(model.visitHorse),
        ])
    }

    /// Applies only a complete graph. Validate untrusted input in an isolated
    /// store before touching the live graph; retain object identity for records
    /// already displayed by an editor or navigation destination.
    static func apply(
        _ records: [SyncRecord], in context: ModelContext,
        journal: SyncJournal? = nil
    ) throws {
        try applyChecked(records, in: context, journal: journal, archive: nil)
    }

    /// Read-only projections must not publish saves from temporary containers.
    /// Keep the decoded graph isolated and validate it without persisting it.
    static func readOnlyGraph(_ records: [SyncRecord]) throws -> ModelContainer {
        let isolated = try ModelContainerFactory.inMemoryTest()
        isolated.mainContext.autosaveEnabled = false
        try populate(records, in: isolated.mainContext)
        try DomainGraphValidator.validateAll(in: isolated.mainContext)
        return isolated
    }

    static func applyRecovery(_ records: [SyncRecord], archive: InvoiceHistoryArchive,
                              in context: ModelContext, journal: SyncJournal) throws {
        try archive.validate()
        try journal.verifyBinding(accountID: archive.accountID, workspaceID: archive.workspaceID)
        guard journal.invoiceHistoryArchives.contains(archive),
              try captureValidated(in: context) == archive.records,
              archive.invoiceIDs.allSatisfy({ id in !records.contains { $0.id == id } }) else {
            throw InvoiceHistoryError.invalidArchive
        }
        try applyChecked(records, in: context, journal: journal, archive: archive)
    }

    private static func applyChecked(_ records: [SyncRecord], in context: ModelContext,
                                     journal: SyncJournal?, archive: InvoiceHistoryArchive?) throws {
        guard !context.hasChanges else { throw SyncGraphError.unsavedChanges }
        let incoming = try SyncJournal.index(records)
        let existing = try captureValidated(in: context)
        let existingByID = try SyncJournal.index(existing)
        for record in records where record.kind == .invoiceLineItem && existingByID[record.id] == nil {
            guard case .string(let value) = record.fields["sourceWorkItem"],
                  let workID = UUID(uuidString: value),
                  let hold = existingByID[workID]?.fields["billingHoldID"], hold != .null else { continue }
            throw BillingHoldError.immutableHold
        }
        for old in existing {
            guard let next = incoming[old.id] else { continue }
            guard old.kind == next.kind else {
                throw SyncJournalError.identityKindChanged(old.id)
            }
            if old.kind == .workItem, let hold = old.fields["billingHoldID"], hold != .null,
               next.fields["billingHoldID"] != hold {
                guard case .string(let value) = hold, let invoiceID = UUID(uuidString: value),
                      next.fields["billingHoldID"] == .null, incoming[invoiceID] == nil,
                      existingByID[invoiceID]?.kind == .invoice ||
                        (journal?.revisions[invoiceID] != nil && journal?.baseline.contains { $0.id == invoiceID } == false)
                else { throw BillingHoldError.immutableHold }
            }
            if [.invoice, .invoiceVisit, .invoiceLineItem, .payment, .photograph].contains(old.kind) {
                var oldFields = old.fields
                var newFields = next.fields
                if old.kind == .invoice {
                    oldFields.removeValue(forKey: "statusRawValue")
                    newFields.removeValue(forKey: "statusRawValue")
                }
                let detachable: String? = switch old.kind {
                case .invoice: "client"
                case .invoiceVisit: "sourceVisit"
                case .invoiceLineItem: "sourceWorkItem"
                default: nil
                }
                if let field = detachable, oldFields[field] != newFields[field],
                   newFields[field] == .null, case .string(let value) = oldFields[field],
                   let sourceID = UUID(uuidString: value) {
                    var mayDetach = incoming[sourceID] == nil
                    if old.kind == .invoiceLineItem,
                       case .string(let groupValue) = old.fields["invoiceVisit"],
                       let groupID = UUID(uuidString: groupValue),
                       let invoice = incoming[groupID]?.fields["invoice"],
                       incoming[sourceID]?.fields["billingHoldID"] == invoice {
                        mayDetach = true
                    }
                    guard mayDetach else { throw SyncGraphError.immutableHistoryChanged }
                    oldFields.removeValue(forKey: field)
                    newFields.removeValue(forKey: field)
                }
                guard oldFields == newFields else {
                    throw SyncGraphError.immutableHistoryChanged
                }
            }
        }
        var invoiceIDsByNumber: [Int64: Set<UUID>] = [:]
        for next in records where next.kind == .invoice {
            if case .integer(let number) = next.fields["number"] {
                invoiceIDsByNumber[number, default: []].insert(next.id)
            }
        }
        let archivedInvoiceIDs = Set(archive?.invoiceIDs ?? [])
        for old in existing where old.kind == .invoice && !archivedInvoiceIDs.contains(old.id) {
            if case .integer(let number) = old.fields["number"],
               let ids = invoiceIDsByNumber[number], ids.contains(where: { $0 != old.id }) {
                throw SyncGraphError.invoiceNumberCollision
            }
        }
        let validationStore = try ModelContainerFactory.inMemoryTest()
        try populate(records, in: validationStore.mainContext)
        try DomainGraphValidator.validateAll(in: validationStore.mainContext)
        do {
            try populate(records, in: context, changedRecords: records.filter { existingByID[$0.id] != $0 })
            try DomainGraphValidator.validateAll(in: context)
            if let journal {
                try SyncJournalStore.write(journal, in: context)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func populate(
        _ records: [SyncRecord], in context: ModelContext, changedRecords: [SyncRecord]? = nil
    ) throws {
        let updates = changedRecords ?? records
        let incoming = try SyncJournal.index(records)
        var businessProfiles = try models(BusinessProfile.self, in: context)
        var clients = try models(Client.self, in: context)
        var barns = try models(Barn.self, in: context)
        var services = try models(Service.self, in: context)
        var horses = try models(Horse.self, in: context)
        var appointments = try models(Appointment.self, in: context)
        var appointmentHorses = try models(AppointmentHorse.self, in: context)
        var visits = try models(Visit.self, in: context)
        var visitHorses = try models(VisitHorse.self, in: context)
        var photographs = try models(Photograph.self, in: context)
        var workItems = try models(WorkItem.self, in: context)
        var invoices = try models(Invoice.self, in: context)
        var invoiceVisits = try models(InvoiceVisit.self, in: context)
        var invoiceLineItems = try models(InvoiceLineItem.self, in: context)
        var payments = try models(Payment.self, in: context)
        // Detach retained financial snapshots before deleting their live sources.
        for (id, model) in invoices where model.client != nil && incoming[id]?.fields["client"] == .null {
            model.detachClient()
        }
        for (id, model) in invoiceVisits where model.sourceVisit != nil && incoming[id]?.fields["sourceVisit"] == .null {
            model.detachSourceVisit()
        }
        for (id, model) in invoiceLineItems where model.sourceWorkItem != nil &&
            (incoming[id]?.fields["sourceWorkItem"] == .null || incoming[id] == nil) {
            model.detachSourceWorkItem()
        }
        for (id, model) in workItems where incoming[id]?.fields["billingHoldID"] == .null {
            if let hold = model.billingHoldID { model.releaseBillingHold(for: hold) }
        }
        for (id, model) in payments where incoming[id] == nil {
            if let invoice = model.invoice, invoice.statusRawValue == InvoiceStatus.paid.rawValue {
                _ = try invoice.removeCompletedPayment()
            }
            context.delete(model)
            payments.removeValue(forKey: id)
        }
        for (id, model) in invoiceLineItems where incoming[id] == nil {
            context.delete(model)
            invoiceLineItems.removeValue(forKey: id)
        }
        for (id, model) in invoiceVisits where incoming[id] == nil {
            context.delete(model)
            invoiceVisits.removeValue(forKey: id)
        }
        for (id, model) in invoices where incoming[id] == nil {
            context.delete(model)
            invoices.removeValue(forKey: id)
        }
        for (id, model) in workItems where incoming[id] == nil {
            model.service?.workItems.removeAll { $0 === model }
            model.visitHorse?.workItems.removeAll { $0 === model }
            model.service = nil
            model.visitHorse = nil
            context.delete(model)
            workItems.removeValue(forKey: id)
        }
        for (id, model) in photographs where incoming[id] == nil {
            context.delete(model)
            photographs.removeValue(forKey: id)
        }
        for (id, model) in visitHorses where incoming[id] == nil {
            context.delete(model)
            visitHorses.removeValue(forKey: id)
        }
        for (id, model) in visits where incoming[id] == nil {
            context.delete(model)
            visits.removeValue(forKey: id)
        }
        for (id, model) in appointmentHorses where incoming[id] == nil {
            context.delete(model)
            appointmentHorses.removeValue(forKey: id)
        }
        for (id, model) in appointments where incoming[id] == nil {
            context.delete(model)
            appointments.removeValue(forKey: id)
        }
        for (id, model) in horses where incoming[id] == nil {
            context.delete(model)
            horses.removeValue(forKey: id)
        }
        for (id, model) in services where incoming[id] == nil {
            context.delete(model)
            services.removeValue(forKey: id)
        }
        for (id, model) in barns where incoming[id] == nil {
            context.delete(model)
            barns.removeValue(forKey: id)
        }
        for (id, model) in clients where incoming[id] == nil {
            context.delete(model)
            clients.removeValue(forKey: id)
        }
        for (id, model) in businessProfiles where incoming[id] == nil {
            context.delete(model)
            businessProfiles.removeValue(forKey: id)
        }
        for record in updates where record.kind == .businessProfile {
            let reader = try SyncRecordReader(record, keys: [
                "name",
                "phone",
                "email",
                "address",
                "defaultInvoiceNote",
                "defaultAppointmentDurationMinutes",
                "defaultInvoiceDueDays",
                "nextInvoiceNumber",
                "currencyCode",
            ])
            let model: BusinessProfile
            if let existing = businessProfiles[record.id] {
                model = existing
            } else {
                model = BusinessProfile(
                    syncID: record.id,
                    name: try reader.string("name"),
                    phone: try reader.optionalString("phone"),
                    email: try reader.optionalString("email"),
                    address: try reader.optionalString("address"),
                    defaultInvoiceNote: try reader.optionalString("defaultInvoiceNote"),
                    defaultAppointmentDurationMinutes: try reader.optionalInt("defaultAppointmentDurationMinutes"),
                    defaultInvoiceDueDays: try reader.optionalInt("defaultInvoiceDueDays"),
                    nextInvoiceNumber: try reader.int64("nextInvoiceNumber"),
                    currencyCode: try reader.string("currencyCode")
                )
                context.insert(model)
                businessProfiles[record.id] = model
            }
            model.name = try reader.string("name")
            model.phone = try reader.optionalString("phone")
            model.email = try reader.optionalString("email")
            model.address = try reader.optionalString("address")
            model.defaultInvoiceNote = try reader.optionalString("defaultInvoiceNote")
            model.defaultAppointmentDurationMinutes = try reader.optionalInt("defaultAppointmentDurationMinutes")
            model.defaultInvoiceDueDays = try reader.optionalInt("defaultInvoiceDueDays")
            model.nextInvoiceNumber = try reader.int64("nextInvoiceNumber")
            model.currencyCode = try reader.string("currencyCode")
        }
        for record in updates where record.kind == .client {
            let reader = try SyncRecordReader(record, keys: [
                "name",
                "phone",
                "email",
                "notes",
            ])
            let model: Client
            if let existing = clients[record.id] {
                model = existing
            } else {
                model = Client(
                    syncID: record.id,
                    name: try reader.string("name"),
                    phone: try reader.optionalString("phone"),
                    email: try reader.optionalString("email"),
                    notes: try reader.optionalString("notes")
                )
                context.insert(model)
                clients[record.id] = model
            }
            model.name = try reader.string("name")
            model.phone = try reader.optionalString("phone")
            model.email = try reader.optionalString("email")
            model.notes = try reader.optionalString("notes")
        }
        for record in updates where record.kind == .barn {
            let reader = try SyncRecordReader(record, keys: [
                "name",
                "address",
                "contactNotes",
            ])
            let model: Barn
            if let existing = barns[record.id] {
                model = existing
            } else {
                model = Barn(
                    syncID: record.id,
                    name: try reader.string("name"),
                    address: try reader.optionalString("address"),
                    contactNotes: try reader.optionalString("contactNotes")
                )
                context.insert(model)
                barns[record.id] = model
            }
            model.name = try reader.string("name")
            model.address = try reader.optionalString("address")
            model.contactNotes = try reader.optionalString("contactNotes")
        }
        for record in updates where record.kind == .service {
            let reader = try SyncRecordReader(record, keys: [
                "name",
                "defaultAmountMinorUnits",
                "currencyCode",
                "isArchived",
            ])
            let model: Service
            if let existing = services[record.id] {
                model = existing
            } else {
                model = Service(
                    syncID: record.id,
                    name: try reader.string("name"),
                    defaultAmountMinorUnits: try reader.int64("defaultAmountMinorUnits"),
                    currencyCode: try reader.string("currencyCode"),
                    isArchived: try reader.bool("isArchived")
                )
                context.insert(model)
                services[record.id] = model
            }
            model.name = try reader.string("name")
            model.defaultAmountMinorUnits = try reader.int64("defaultAmountMinorUnits")
            model.currencyCode = try reader.string("currencyCode")
            model.isArchived = try reader.bool("isArchived")
        }
        for record in updates where record.kind == .horse {
            let reader = try SyncRecordReader(record, keys: [
                "name",
                "safetyNotes",
                "appointmentIntervalWeeks",
                "client",
                "currentBarn",
                "defaultService",
            ])
            let model: Horse
            if let existing = horses[record.id] {
                model = existing
            } else {
                model = Horse(
                    syncID: record.id,
                    name: try reader.string("name"),
                    safetyNotes: try reader.optionalString("safetyNotes"),
                    appointmentIntervalWeeks: try reader.int("appointmentIntervalWeeks"),
                    client: try reader.model("client", from: clients),
                    currentBarn: try reader.model("currentBarn", from: barns),
                    defaultService: try reader.optionalModel("defaultService", from: services)
                )
                context.insert(model)
                horses[record.id] = model
            }
            model.name = try reader.string("name")
            model.safetyNotes = try reader.optionalString("safetyNotes")
            model.appointmentIntervalWeeks = try reader.int("appointmentIntervalWeeks")
            model.client = try reader.model("client", from: clients)
            model.currentBarn = try reader.model("currentBarn", from: barns)
            model.defaultService = try reader.optionalModel("defaultService", from: services)
        }
        for record in updates where record.kind == .appointment {
            let reader = try SyncRecordReader(record, keys: [
                "startDate",
                "notes",
                "expectedDurationMinutes",
                "barn",
            ])
            let model: Appointment
            if let existing = appointments[record.id] {
                model = existing
            } else {
                model = Appointment(
                    syncID: record.id,
                    startDate: try reader.date("startDate"),
                    notes: try reader.optionalString("notes"),
                    expectedDurationMinutes: try reader.optionalInt("expectedDurationMinutes"),
                    barn: try reader.model("barn", from: barns)
                )
                context.insert(model)
                appointments[record.id] = model
            }
            model.startDate = try reader.date("startDate")
            model.notes = try reader.optionalString("notes")
            model.expectedDurationMinutes = try reader.optionalInt("expectedDurationMinutes")
            model.barn = try reader.model("barn", from: barns)
        }
        for record in updates where record.kind == .appointmentHorse {
            let reader = try SyncRecordReader(record, keys: [
                "appointment",
                "horse",
            ], optionalKeys: ["plannedService"])
            let model: AppointmentHorse
            if let existing = appointmentHorses[record.id] {
                model = existing
            } else {
                model = AppointmentHorse(
                    syncID: record.id,
                    appointment: try reader.model("appointment", from: appointments),
                    horse: try reader.model("horse", from: horses)
                )
                context.insert(model)
                appointmentHorses[record.id] = model
            }
            model.appointment = try reader.model("appointment", from: appointments)
            model.horse = try reader.model("horse", from: horses)
            model.plannedService = record.fields["plannedService"] == nil
                ? nil : try reader.optionalModel("plannedService", from: services)
        }
        for record in updates where record.kind == .visit {
            let reader = try SyncRecordReader(record, keys: [
                "startedAt",
                "completedAt",
                "serviceLocationNameSnapshot",
                "serviceLocationAddressSnapshot",
                "appointment",
                "barn",
            ])
            let model: Visit
            if let existing = visits[record.id] {
                model = existing
            } else {
                model = Visit(
                    syncID: record.id,
                    startedAt: try reader.date("startedAt"),
                    completedAt: try reader.optionalDate("completedAt"),
                    serviceLocationNameSnapshot: try reader.string("serviceLocationNameSnapshot"),
                    serviceLocationAddressSnapshot: try reader.optionalString("serviceLocationAddressSnapshot"),
                    appointment: try reader.model("appointment", from: appointments),
                    barn: try reader.model("barn", from: barns)
                )
                context.insert(model)
                visits[record.id] = model
            }
            model.startedAt = try reader.date("startedAt")
            model.completedAt = try reader.optionalDate("completedAt")
            model.serviceLocationNameSnapshot = try reader.string("serviceLocationNameSnapshot")
            model.serviceLocationAddressSnapshot = try reader.optionalString("serviceLocationAddressSnapshot")
            model.appointment = try reader.model("appointment", from: appointments)
            model.barn = try reader.model("barn", from: barns)
        }
        for record in updates where record.kind == .visitHorse {
            let reader = try SyncRecordReader(record, keys: [
                "outcomeRawValue",
                "workNotes",
                "visit",
                "horse",
            ])
            let model: VisitHorse
            if let existing = visitHorses[record.id] {
                model = existing
            } else {
                model = VisitHorse(
                    syncID: record.id,
                    outcomeRawValue: try reader.string("outcomeRawValue"),
                    workNotes: try reader.optionalString("workNotes"),
                    visit: try reader.model("visit", from: visits),
                    horse: try reader.model("horse", from: horses)
                )
                context.insert(model)
                visitHorses[record.id] = model
            }
            model.outcomeRawValue = try reader.string("outcomeRawValue")
            model.workNotes = try reader.optionalString("workNotes")
            model.visit = try reader.model("visit", from: visits)
            model.horse = try reader.model("horse", from: horses)
        }
        for record in updates where record.kind == .photograph {
            let reader = try SyncRecordReader(record, keys: [
                "createdAt",
                "pixelWidth",
                "pixelHeight",
                "byteCount",
                "visitHorse",
            ])
            let model: Photograph
            if let existing = photographs[record.id] {
                model = existing
            } else {
                model = Photograph(
                    id: record.id,
                    createdAt: try reader.date("createdAt"),
                    pixelWidth: try reader.int("pixelWidth"),
                    pixelHeight: try reader.int("pixelHeight"),
                    byteCount: try reader.int64("byteCount"),
                    visitHorse: try reader.model("visitHorse", from: visitHorses)
                )
                context.insert(model)
                photographs[record.id] = model
            }
        }
        for record in updates where record.kind == .workItem {
            let reader = try SyncRecordReader(record, keys: [
                "serviceNameSnapshot",
                "amountMinorUnits",
                "currencyCode",
                "service",
                "visitHorse",
            ], optionalKeys: ["billingHoldID"])
            let model: WorkItem
            if let existing = workItems[record.id] {
                model = existing
            } else {
                model = WorkItem(
                    syncID: record.id,
                    serviceNameSnapshot: try reader.string("serviceNameSnapshot"),
                    amountMinorUnits: try reader.int64("amountMinorUnits"),
                    currencyCode: try reader.string("currencyCode"),
                    service: try reader.model("service", from: services),
                    visitHorse: try reader.model("visitHorse", from: visitHorses)
                )
                context.insert(model)
                workItems[record.id] = model
            }
            model.serviceNameSnapshot = try reader.string("serviceNameSnapshot")
            model.amountMinorUnits = try reader.int64("amountMinorUnits")
            model.currencyCode = try reader.string("currencyCode")
            model.service = try reader.model("service", from: services)
            model.visitHorse = try reader.model("visitHorse", from: visitHorses)
            if let holdID = try reader.optionalUUID("billingHoldID") {
                try model.applyBillingHold(holdID)
            }
        }
        for record in updates where record.kind == .invoice {
            let reader = try SyncRecordReader(record, keys: [
                "number",
                "invoiceDate",
                "dueDate",
                "note",
                "statusRawValue",
                "clientNameSnapshot",
                "clientPhoneSnapshot",
                "clientEmailSnapshot",
                "businessNameSnapshot",
                "businessPhoneSnapshot",
                "businessEmailSnapshot",
                "businessAddressSnapshot",
                "currencyCode",
                "client",
            ])
            let model: Invoice
            if let existing = invoices[record.id] {
                model = existing
            } else {
                model = Invoice(
                    syncID: record.id,
                    number: try reader.int64("number"),
                    invoiceDate: try reader.date("invoiceDate"),
                    dueDate: try reader.optionalDate("dueDate"),
                    note: try reader.optionalString("note"),
                    clientNameSnapshot: try reader.string("clientNameSnapshot"),
                    clientPhoneSnapshot: try reader.optionalString("clientPhoneSnapshot"),
                    clientEmailSnapshot: try reader.optionalString("clientEmailSnapshot"),
                    businessNameSnapshot: try reader.string("businessNameSnapshot"),
                    businessPhoneSnapshot: try reader.optionalString("businessPhoneSnapshot"),
                    businessEmailSnapshot: try reader.optionalString("businessEmailSnapshot"),
                    businessAddressSnapshot: try reader.optionalString("businessAddressSnapshot"),
                    currencyCode: try reader.string("currencyCode"),
                    client: try reader.optionalModel("client", from: clients)
                )
                context.insert(model)
                invoices[record.id] = model
            }
        }
        for record in updates where record.kind == .invoiceVisit {
            let reader = try SyncRecordReader(record, keys: [
                "visitDateSnapshot",
                "serviceLocationNameSnapshot",
                "serviceLocationAddressSnapshot",
                "invoice",
                "sourceVisit",
            ])
            let model: InvoiceVisit
            if let existing = invoiceVisits[record.id] {
                model = existing
            } else {
                model = InvoiceVisit(
                    syncID: record.id,
                    visitDateSnapshot: try reader.date("visitDateSnapshot"),
                    serviceLocationNameSnapshot: try reader.string("serviceLocationNameSnapshot"),
                    serviceLocationAddressSnapshot: try reader.optionalString("serviceLocationAddressSnapshot"),
                    invoice: try reader.model("invoice", from: invoices),
                    sourceVisit: try reader.optionalModel("sourceVisit", from: visits)
                )
                context.insert(model)
                invoiceVisits[record.id] = model
            }
        }
        for record in updates where record.kind == .invoiceLineItem {
            let reader = try SyncRecordReader(record, keys: [
                "horseNameSnapshot",
                "serviceNameSnapshot",
                "amountMinorUnits",
                "currencyCode",
                "invoiceVisit",
                "sourceWorkItem",
            ])
            let model: InvoiceLineItem
            if let existing = invoiceLineItems[record.id] {
                model = existing
            } else {
                model = InvoiceLineItem(
                    syncID: record.id,
                    horseNameSnapshot: try reader.string("horseNameSnapshot"),
                    serviceNameSnapshot: try reader.string("serviceNameSnapshot"),
                    amountMinorUnits: try reader.int64("amountMinorUnits"),
                    currencyCode: try reader.string("currencyCode"),
                    invoiceVisit: try reader.model("invoiceVisit", from: invoiceVisits),
                    sourceWorkItem: try reader.optionalModel("sourceWorkItem", from: workItems)
                )
                context.insert(model)
                invoiceLineItems[record.id] = model
            }
        }
        for record in updates where record.kind == .payment {
            let reader = try SyncRecordReader(record, keys: [
                "amountMinorUnits",
                "currencyCode",
                "receivedAt",
                "methodRawValue",
                "sourceRawValue",
                "otherDescription",
                "reference",
                "note",
                "invoice",
            ])
            guard let method = PaymentMethod(rawValue: try reader.string("methodRawValue")),
                  let source = PaymentRecordSource(rawValue: try reader.string("sourceRawValue")) else {
                throw SyncGraphError.invalidField("payment")
            }
            let model: Payment
            if let existing = payments[record.id] {
                model = existing
            } else {
                model = Payment(
                    id: record.id,
                    amountMinorUnits: try reader.int64("amountMinorUnits"),
                    currencyCode: try reader.string("currencyCode"),
                    receivedAt: try reader.date("receivedAt"),
                    method: method,
                    source: source,
                    otherDescription: try reader.optionalString("otherDescription"),
                    reference: try reader.optionalString("reference"),
                    note: try reader.optionalString("note"),
                    invoice: try reader.model("invoice", from: invoices)
                )
                context.insert(model)
                payments[record.id] = model
            }
            guard let invoice = model.invoice else {
                throw SyncGraphError.missingRelationship("invoice")
            }
            if invoice.statusRawValue == InvoiceStatus.unpaid.rawValue {
                try invoice.recordCompletedPayment(model)
            }
        }
        for record in records where record.kind == .invoice {
            guard let invoice = invoices[record.id],
                  record.fields["statusRawValue"] == .string(invoice.statusRawValue) else {
                throw SyncGraphError.invalidField("statusRawValue")
            }
        }
    }

    private static func models<T: SyncRecordIdentifying>(
        _ type: T.Type, in context: ModelContext
    ) throws -> [UUID: T] {
        let records = try context.fetch(FetchDescriptor<T>())
        let ids = try SyncRecordIdentity.requireIDs(records)
        return Dictionary(uniqueKeysWithValues: zip(ids, records))
    }

    private static func text(_ value: String?) -> SyncValue {
        value.map(SyncValue.string) ?? .null
    }

    private static func integer(_ value: Int?) -> SyncValue {
        value.map { .integer(Int64($0)) } ?? .null
    }

    private static func date(_ value: Date?) throws -> SyncValue {
        guard let value else { return .null }
        let seconds = value.timeIntervalSinceReferenceDate
        guard seconds.isFinite else { throw SyncGraphError.invalidField("date") }
        // Round-trippable reference-date seconds avoid truncating Date precision.
        return .string(String(seconds))
    }

    private static func reference<T: SyncRecordIdentifying>(_ model: T?) throws -> SyncValue {
        guard let model else { return .null }
        guard let id = model.syncID else { throw SyncIdentityError.missingIdentity }
        return .string(id.uuidString.lowercased())
    }
}

@MainActor
private struct SyncRecordReader {
    let record: SyncRecord

    init(_ record: SyncRecord, keys: Set<String>, optionalKeys: Set<String> = []) throws {
        let actual = Set(record.fields.keys)
        guard keys.isSubset(of: actual), actual.isSubset(of: keys.union(optionalKeys)) else {
            throw SyncGraphError.invalidField(record.kind.rawValue)
        }
        self.record = record
    }

    func optionalUUID(_ key: String) throws -> UUID? {
        guard let field = record.fields[key], field != .null else { return nil }
        let value = try string(key)
        guard let id = UUID(uuidString: value), id.uuidString.lowercased() == value else {
            throw SyncGraphError.invalidField(key)
        }
        return id
    }

    func string(_ key: String) throws -> String {
        guard case .string(let value) = record.fields[key],
              value.utf8.count <= 65_536 else { throw SyncGraphError.invalidField(key) }
        return value
    }

    func optionalString(_ key: String) throws -> String? {
        if record.fields[key] == .null { return nil }
        return try string(key)
    }

    func int64(_ key: String) throws -> Int64 {
        guard case .integer(let value) = record.fields[key] else {
            throw SyncGraphError.invalidField(key)
        }
        return value
    }

    func int(_ key: String) throws -> Int {
        guard let value = Int(exactly: try int64(key)) else {
            throw SyncGraphError.invalidField(key)
        }
        return value
    }

    func optionalInt(_ key: String) throws -> Int? {
        if record.fields[key] == .null { return nil }
        return try int(key)
    }

    func bool(_ key: String) throws -> Bool {
        guard case .boolean(let value) = record.fields[key] else {
            throw SyncGraphError.invalidField(key)
        }
        return value
    }

    func date(_ key: String) throws -> Date {
        guard let seconds = Double(try string(key)), seconds.isFinite,
              abs(seconds) <= 1_000_000_000_000 else {
            throw SyncGraphError.invalidField(key)
        }
        return Date(timeIntervalSinceReferenceDate: seconds)
    }

    func optionalDate(_ key: String) throws -> Date? {
        if record.fields[key] == .null { return nil }
        return try date(key)
    }

    func model<T: PersistentModel>(_ key: String, from models: [UUID: T]) throws -> T {
        guard let id = UUID(uuidString: try string(key)), let model = models[id] else {
            throw SyncGraphError.missingRelationship(key)
        }
        return model
    }

    func optionalModel<T: PersistentModel>(_ key: String, from models: [UUID: T]) throws -> T? {
        if record.fields[key] == .null { return nil }
        return try model(key, from: models)
    }
}
