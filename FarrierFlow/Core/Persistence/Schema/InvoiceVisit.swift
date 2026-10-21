import Foundation
import SwiftData

extension FarrierFlowSchemaV5 {
    @Model
    final class InvoiceVisit: SyncRecordIdentifying {
        private(set) var syncID: UUID?

        func initializeSyncIdentity() {
            if syncID == nil { syncID = UUID() }
        }

        private(set) var visitDateSnapshot: Date
        private(set) var serviceLocationNameSnapshot: String
        private(set) var serviceLocationAddressSnapshot: String?
        private(set) var invoice: Invoice?
        private(set) var sourceVisit: Visit?

        @Relationship(
            deleteRule: .cascade,
            minimumModelCount: 1,
            inverse: \InvoiceLineItem.invoiceVisit
        )
        var lineItems: [InvoiceLineItem] = []

        func detachSourceVisit() {
            sourceVisit?.invoiceVisits.removeAll { $0 === self }
            sourceVisit = nil
        }

        init(
            syncID: UUID = UUID(),
            visitDateSnapshot: Date,
            serviceLocationNameSnapshot: String,
            serviceLocationAddressSnapshot: String? = nil,
            invoice: Invoice,
            sourceVisit: Visit?
        ) {
            self.syncID = syncID
            self.visitDateSnapshot = visitDateSnapshot
            self.serviceLocationNameSnapshot = serviceLocationNameSnapshot
            self.serviceLocationAddressSnapshot = serviceLocationAddressSnapshot
            self.invoice = invoice
            self.sourceVisit = sourceVisit
        }
    }
}
