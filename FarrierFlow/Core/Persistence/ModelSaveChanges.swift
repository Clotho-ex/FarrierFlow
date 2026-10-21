import Combine
import Foundation
import SwiftData

@MainActor
enum ModelSaveChanges {
    static func identifiers(in notification: Notification) -> [PersistentIdentifier] {
        let keys: [ModelContext.NotificationKey] = [.insertedIdentifiers, .updatedIdentifiers, .deletedIdentifiers]
        return keys.flatMap { key in
            let value = notification.userInfo?[key.rawValue] ?? notification.userInfo?[key]
            if let identifiers = value as? [PersistentIdentifier] { return identifiers }
            if let identifiers = value as? Set<PersistentIdentifier> { return Array(identifiers) }
            return []
        }
    }

    static func affects(_ notification: Notification, container: ModelContainer, entities: Set<String>) -> Bool {
        guard let context = notification.object as? ModelContext, context.container === container else { return false }
        let changed = identifiers(in: notification)
        // Older runtimes can omit identifiers. Reload conservatively in that case.
        return changed.isEmpty || changed.contains { entities.contains($0.entityName) }
    }

    static func publisher(in container: ModelContainer, entities: Set<String>) -> AnyPublisher<Void, Never> {
        NotificationCenter.default.publisher(for: ModelContext.didSave)
            // Inspect foreign contexts before SwiftUI can buffer the notification
            // beyond the lifetime of a temporary validation container.
            .filter { affects($0, container: container, entities: entities) }
            .map { _ in () }
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
