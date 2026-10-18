import Foundation
import SwiftData

extension FarrierFlowSchemaV5 {
    @Model
    final class Photograph: SyncRecordIdentifying {
        var syncID: UUID? { id }

        func initializeSyncIdentity() { }

        @Attribute(.unique) var id: UUID
        var createdAt: Date
        var pixelWidth: Int
        var pixelHeight: Int
        var byteCount: Int64
        var visitHorse: VisitHorse?

        init(
            id: UUID,
            createdAt: Date,
            pixelWidth: Int,
            pixelHeight: Int,
            byteCount: Int64,
            visitHorse: VisitHorse
        ) {
            self.id = id
            self.createdAt = createdAt
            self.pixelWidth = pixelWidth
            self.pixelHeight = pixelHeight
            self.byteCount = byteCount
            self.visitHorse = visitHorse
        }
    }
}
