import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Payment recording analytics", .serialized)
@MainActor
struct PaymentRecordingModelTests {
    @Test(arguments: ["description", "reference", "note"])
    func oversizedInputCannotRecordPayment(_ field: String) throws {
        let graph = try InvoiceActionGraph.make()
        let model = PaymentRecordingModel(invoiceID: graph.invoiceID, amountMinorUnits: 12_500, currencyCode: "USD")
        model.draft.method = .cash
        switch field {
        case "description": model.draft.otherDescription = String(repeating: "a", count: 61)
        case "reference": model.draft.reference = String(repeating: "a", count: 101)
        default: model.draft.note = String(repeating: "a", count: 501)
        }
        #expect(!model.canConfirm)
        model.confirm(in: graph.context)
        #expect(!model.didRecord)
        #expect(model.alert != nil)
        let invoice = try #require(try graph.context.existingModel(Invoice.self, for: graph.invoiceID))
        #expect(invoice.payments.isEmpty)
        #expect(invoice.statusRawValue == InvoiceStatus.unpaid.rawValue)
    }

    @Test
    func persistedPaidTransitionEmitsAndFailedDuplicateDoesNot() throws {
        let graph = try InvoiceActionGraph.make()
        let analytics = AnalyticsSpy()
        let model = PaymentRecordingModel(
            invoiceID: graph.invoiceID,
            amountMinorUnits: 12_500,
            currencyCode: "USD"
        )
        model.draft.method = .cash

        model.confirm(in: graph.context, analyticsClient: analytics)

        #expect(model.didRecord)
        #expect(analytics.events == [.invoiceMarkedPaid])

        let reconstructed = PaymentRecordingModel(
            invoiceID: graph.invoiceID,
            amountMinorUnits: 12_500,
            currencyCode: "USD"
        )
        reconstructed.draft.method = .cash
        reconstructed.confirm(in: graph.context, analyticsClient: analytics)

        #expect(!reconstructed.didRecord)
        #expect(analytics.events == [.invoiceMarkedPaid])
    }

    @Test
    func paidToUnpaidToPaidIsASecondTruthfulTransition() throws {
        let graph = try InvoiceActionGraph.make(status: .paid)
        let analytics = AnalyticsSpy()
        try InvoicePaymentUseCase.markUnpaid(
            invoiceID: graph.invoiceID,
            in: graph.context
        )
        let model = PaymentRecordingModel(
            invoiceID: graph.invoiceID,
            amountMinorUnits: 12_500,
            currencyCode: "USD"
        )
        model.draft.method = .card

        model.confirm(in: graph.context, analyticsClient: analytics)

        #expect(analytics.events == [.invoiceMarkedPaid])
    }
}
