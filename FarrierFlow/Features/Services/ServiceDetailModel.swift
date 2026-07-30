import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ServiceDetailModel {
    private(set) var service: Service?
    var alert: FeatureAlert?

    func load(id: PersistentIdentifier, in context: ModelContext) {
        service = context.model(for: id) as? Service
    }

    func archive(in context: ModelContext) -> Bool {
        guard let service else { return false }
        do {
            try RecordDeletionRules.archive(service, in: context)
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
        guard let service else { return false }
        guard service.isArchived else { return true }
        service.isArchived = false
        do {
            try DomainGraphValidator.save(context)
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

    func delete(in context: ModelContext) -> Bool {
        guard let service else { return false }
        self.service = nil
        do {
            try RecordDeletionRules.delete(service, in: context)
            return true
        } catch let block as RecordDeletionBlock {
            self.service = service
            alert = block.alert
            return false
        } catch {
            self.service = service
            alert = FeatureAlert(
                title: "Couldn’t Delete Service",
                message: "The service wasn’t deleted. Try again."
            )
            return false
        }
    }
}
