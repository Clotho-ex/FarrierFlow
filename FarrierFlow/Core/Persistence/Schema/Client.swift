import Foundation
import SwiftData

extension FarrierFlowSchemaV5 {
    @Model
    final class Client: SyncRecordIdentifying {
        private(set) var syncID: UUID?

        func initializeSyncIdentity() {
            if syncID == nil { syncID = UUID() }
        }

        var name: String
        var phone: String?
        var email: String?
        var notes: String?

        @Relationship(deleteRule: .deny, inverse: \Horse.client)
        var horses: [Horse] = []

        @Relationship(deleteRule: .deny, inverse: \Invoice.client)
        var invoices: [Invoice] = []

        init(
            syncID: UUID = UUID(),
            name: String,
            phone: String? = nil,
            email: String? = nil,
            notes: String? = nil
        ) {
            self.syncID = syncID
            self.name = name
            self.phone = phone
            self.email = email
            self.notes = notes
        }
    }
}
