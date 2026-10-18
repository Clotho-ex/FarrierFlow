import Foundation
import SwiftData

extension FarrierFlowSchemaV5 {
    /// Device/account metadata is local only and never part of the business graph.
    @Model
    final class SyncState {
        @Attribute(.unique) var slot: String
        var deviceID: UUID
        var journalData: Data?
        var cloudDeleted: Bool = false

        init(slot: String = "solo", deviceID: UUID = UUID()) {
            self.slot = slot
            self.deviceID = deviceID
        }
    }
}
