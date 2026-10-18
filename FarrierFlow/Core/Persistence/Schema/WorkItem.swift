import Foundation
import SwiftData

nonisolated enum BillingHoldError: Error, Equatable {
    case immutableHold
}

extension FarrierFlowSchemaV5 {
    @Model
    final class WorkItem: SyncRecordIdentifying {
        private(set) var syncID: UUID?

        func initializeSyncIdentity() {
            if syncID == nil { syncID = UUID() }
        }

        var serviceNameSnapshot: String
        var amountMinorUnits: Int64
        var currencyCode: String
        private(set) var billingHoldID: UUID?
        var service: Service?
        var visitHorse: VisitHorse?

        @Relationship(deleteRule: .deny, inverse: \InvoiceLineItem.sourceWorkItem)
        var invoiceLineItem: InvoiceLineItem?

        func applyBillingHold(_ invoiceID: UUID) throws {
            guard billingHoldID == nil || billingHoldID == invoiceID else {
                throw BillingHoldError.immutableHold
            }
            billingHoldID = invoiceID
        }

        init(
            syncID: UUID = UUID(),
            serviceNameSnapshot: String,
            amountMinorUnits: Int64,
            currencyCode: String = "USD",
            service: Service,
            visitHorse: VisitHorse
        ) {
            self.syncID = syncID
            self.serviceNameSnapshot = serviceNameSnapshot
            self.amountMinorUnits = amountMinorUnits
            self.currencyCode = currencyCode
            self.service = service
            self.visitHorse = visitHorse
        }
    }
}
