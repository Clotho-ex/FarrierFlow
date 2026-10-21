import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ServiceDetailModel {
    private(set) var service: ServiceDetailSnapshot?
    private(set) var usage = RecordUsageSnapshot()
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        do {
            if let record = try context.existingModel(Service.self, for: id) {
                usage = try RecordUsageSnapshot(service: record)
                service = ServiceDetailSnapshot(service: record)
            } else {
                service = nil
                usage = RecordUsageSnapshot()
            }
        } catch {
            service = nil
            usage = RecordUsageSnapshot()
            alert = FeatureAlert(
                title: "Service Unavailable",
                message: "The service couldn’t be loaded. Try again."
            )
        }
    }

    func archive(in context: ModelContext) -> Bool {
        do {
            guard let id = service?.id,
                  let record = try context.existingModel(Service.self, for: id) else {
                alert = unavailableAlert
                return false
            }
            try RecordDeletionRules.archive(record, in: context)
            service = ServiceDetailSnapshot(service: record)
            return true
        } catch RecordDeletionBlock.serviceHasHorseDefaults {
            alert = FeatureAlert(
                title: "Can’t Archive Service",
                message: "Clear or replace every Horse default first."
            )
            return false
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Archive Service",
                message: "The service remains active. Try again."
            )
            return false
        }
    }

    func reactivate(in context: ModelContext) -> Bool {
        do {
            guard let id = service?.id,
                  let record = try context.existingModel(Service.self, for: id) else {
                alert = unavailableAlert
                return false
            }
            if record.isArchived {
                record.isArchived = false
                try DomainGraphValidator.save(context)
            }
            service = ServiceDetailSnapshot(service: record)
            return true
        } catch {
            context.rollback()
            alert = FeatureAlert(
                title: "Couldn’t Reactivate Service",
                message: "The service remains archived. Try again."
            )
            return false
        }
    }

    func delete(
        in context: ModelContext,
        deleting: (Service, ModelContext) throws -> Void = { record, context in
            try RecordDeletionRules.delete(record, in: context)
        }
    ) -> Bool {
        guard let displayed = service else {
            alert = unavailableAlert
            return false
        }
        do {
            guard let record = try context.existingModel(Service.self, for: displayed.id) else {
                alert = unavailableAlert
                return false
            }
            try deleting(record, context)
            service = nil
            alert = nil
            return true
        } catch let block as RecordDeletionBlock {
            alert = block.alert
            return false
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Delete Service",
                message: "The service wasn’t deleted. Try again."
            )
            return false
        }
    }

    private var unavailableAlert: FeatureAlert {
        FeatureAlert(
            title: "Service Unavailable",
            message: "This service is no longer available."
        )
    }
}
