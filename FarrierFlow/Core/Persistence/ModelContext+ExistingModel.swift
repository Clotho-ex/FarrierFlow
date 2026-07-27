import Foundation
import SwiftData

extension ModelContext {
    func existingModel<Model: PersistentModel>(
        _ type: Model.Type,
        for id: PersistentIdentifier
    ) throws -> Model? {
        let descriptor = FetchDescriptor<Model>(
            predicate: #Predicate<Model> { model in
                model.persistentModelID == id
            }
        )
        return try fetch(descriptor).first
    }
}
