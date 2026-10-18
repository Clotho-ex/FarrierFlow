import Foundation
import SwiftData

nonisolated protocol SyncRecordIdentifying: PersistentModel {
    var syncID: UUID? { get }
    func initializeSyncIdentity()
}

nonisolated enum SyncIdentityError: Error, Equatable {
    case missingIdentity
    case duplicateIdentity(UUID)
}

nonisolated enum SyncRecordIdentity {
    static func requireIDs<T: SyncRecordIdentifying>(_ records: [T]) throws -> [UUID] {
        var seen: Set<UUID> = []
        return try records.map { record in
            guard let id = record.syncID else { throw SyncIdentityError.missingIdentity }
            guard seen.insert(id).inserted else { throw SyncIdentityError.duplicateIdentity(id) }
            return id
        }
    }

    static func initializeAll(in context: ModelContext) throws {
        try initialize(Client.self, in: context)
        try initialize(Barn.self, in: context)
        try initialize(Horse.self, in: context)
        try initialize(Appointment.self, in: context)
        try initialize(AppointmentHorse.self, in: context)
        try initialize(Visit.self, in: context)
        try initialize(VisitHorse.self, in: context)
        try initialize(Photograph.self, in: context)
        try initialize(Service.self, in: context)
        try initialize(WorkItem.self, in: context)
        try initialize(BusinessProfile.self, in: context)
        try initialize(Invoice.self, in: context)
        try initialize(InvoiceVisit.self, in: context)
        try initialize(InvoiceLineItem.self, in: context)
        try initialize(Payment.self, in: context)
        try context.save()
    }

    static func initializeV3(in context: ModelContext) throws {
        try initialize(FarrierFlowSchemaV3.Client.self, in: context)
        try initialize(FarrierFlowSchemaV3.Barn.self, in: context)
        try initialize(FarrierFlowSchemaV3.Horse.self, in: context)
        try initialize(FarrierFlowSchemaV3.Appointment.self, in: context)
        try initialize(FarrierFlowSchemaV3.AppointmentHorse.self, in: context)
        try initialize(FarrierFlowSchemaV3.Visit.self, in: context)
        try initialize(FarrierFlowSchemaV3.VisitHorse.self, in: context)
        try initialize(FarrierFlowSchemaV3.Photograph.self, in: context)
        try initialize(FarrierFlowSchemaV3.Service.self, in: context)
        try initialize(FarrierFlowSchemaV3.WorkItem.self, in: context)
        try initialize(FarrierFlowSchemaV3.BusinessProfile.self, in: context)
        try initialize(FarrierFlowSchemaV3.Invoice.self, in: context)
        try initialize(FarrierFlowSchemaV3.InvoiceVisit.self, in: context)
        try initialize(FarrierFlowSchemaV3.InvoiceLineItem.self, in: context)
        try initialize(FarrierFlowSchemaV3.Payment.self, in: context)
        try context.save()
    }

    private static func initialize<T: SyncRecordIdentifying>(
        _ type: T.Type,
        in context: ModelContext
    ) throws {
        let records = try context.fetch(FetchDescriptor<T>())
        for record in records { record.initializeSyncIdentity() }
        _ = try requireIDs(records)
    }
}
