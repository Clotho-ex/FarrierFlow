import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Invoice status use case", .serialized)
@MainActor
struct InvoiceStatusUseCaseTests {
    @Test
    func markPaidPersistsThePaidStatusAndExactPaymentDate() throws {
        let graph = try InvoiceActionGraph.make()
        let paidAt = Date(timeIntervalSinceReferenceDate: 999)

        try InvoiceStatusUseCase.markPaid(invoiceID: graph.invoiceID, paidAt: paidAt, in: graph.context)

        let invoice = try #require(graph.context.model(for: graph.invoiceID) as? Invoice)
        #expect(invoice.statusRawValue == InvoiceStatus.paid.rawValue)
        #expect(invoice.paidAt == paidAt)
        #expect(throws: InvoiceStatusError.invoiceAlreadyPaid) {
            try InvoiceStatusUseCase.markPaid(invoiceID: graph.invoiceID, paidAt: paidAt, in: graph.context)
        }
    }
}
