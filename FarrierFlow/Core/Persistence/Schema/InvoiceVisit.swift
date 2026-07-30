import Foundation
import SwiftData

extension FarrierFlowSchemaV1 {
    @Model
    final class InvoiceVisit {
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

        init(
            visitDateSnapshot: Date,
            serviceLocationNameSnapshot: String,
            serviceLocationAddressSnapshot: String? = nil,
            invoice: Invoice,
            sourceVisit: Visit
        ) {
            self.visitDateSnapshot = visitDateSnapshot
            self.serviceLocationNameSnapshot = serviceLocationNameSnapshot
            self.serviceLocationAddressSnapshot = serviceLocationAddressSnapshot
            self.invoice = invoice
            self.sourceVisit = sourceVisit
        }
    }
}
