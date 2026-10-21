import Foundation
import SwiftData

extension FarrierFlowSchemaV5 {
    @Model
    final class InvoiceLineItem: SyncRecordIdentifying {
        private(set) var syncID: UUID?

        func initializeSyncIdentity() {
            if syncID == nil { syncID = UUID() }
        }

        private(set) var horseNameSnapshot: String
        private(set) var serviceNameSnapshot: String
        private(set) var amountMinorUnits: Int64
        private(set) var currencyCode: String
        private(set) var invoiceVisit: InvoiceVisit?
        private(set) var sourceWorkItem: WorkItem?

        func detachSourceWorkItem() {
            sourceWorkItem?.invoiceLineItem = nil
            sourceWorkItem = nil
        }

        init(
            syncID: UUID = UUID(),
            horseNameSnapshot: String,
            serviceNameSnapshot: String,
            amountMinorUnits: Int64,
            currencyCode: String = "USD",
            invoiceVisit: InvoiceVisit,
            sourceWorkItem: WorkItem?
        ) {
            self.syncID = syncID
            self.horseNameSnapshot = horseNameSnapshot
            self.serviceNameSnapshot = serviceNameSnapshot
            self.amountMinorUnits = amountMinorUnits
            self.currencyCode = currencyCode
            self.invoiceVisit = invoiceVisit
            self.sourceWorkItem = sourceWorkItem
        }
    }
}
