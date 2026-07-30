import SwiftData

extension FarrierFlowSchemaV1 {
    @Model
    final class InvoiceLineItem {
        private(set) var horseNameSnapshot: String
        private(set) var serviceNameSnapshot: String
        private(set) var amountMinorUnits: Int64
        private(set) var currencyCode: String
        private(set) var invoiceVisit: InvoiceVisit?
        private(set) var sourceWorkItem: WorkItem?

        init(
            horseNameSnapshot: String,
            serviceNameSnapshot: String,
            amountMinorUnits: Int64,
            currencyCode: String = "USD",
            invoiceVisit: InvoiceVisit,
            sourceWorkItem: WorkItem
        ) {
            self.horseNameSnapshot = horseNameSnapshot
            self.serviceNameSnapshot = serviceNameSnapshot
            self.amountMinorUnits = amountMinorUnits
            self.currencyCode = currencyCode
            self.invoiceVisit = invoiceVisit
            self.sourceWorkItem = sourceWorkItem
        }
    }
}
