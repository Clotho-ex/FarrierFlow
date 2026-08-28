import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Invoice payment use case", .serialized)
@MainActor
struct InvoicePaymentUseCaseTests {
    @Test(arguments: PaymentMethod.allCases)
    func recordsEveryManualPaymentMethod(_ method: PaymentMethod) throws {
        let graph = try InvoiceActionGraph.make()
        let receivedAt = Date(timeIntervalSinceReferenceDate: 999)

        try InvoicePaymentUseCase.recordPayment(
            invoiceID: graph.invoiceID,
            method: method,
            receivedAt: receivedAt,
            otherDescription: method == .other ? "Mobile wallet" : nil,
            reference: "  Ref 42  ",
            note: "  Office only  ",
            in: graph.context
        )

        let invoice = try #require(graph.context.model(for: graph.invoiceID) as? Invoice)
        let payment = try #require(invoice.payments.first)
        #expect(invoice.statusRawValue == InvoiceStatus.paid.rawValue)
        #expect(invoice.payments.count == 1)
        #expect(payment.amountMinorUnits == 12_500)
        #expect(payment.currencyCode == "USD")
        #expect(payment.receivedAt == receivedAt)
        #expect(payment.method == method)
        #expect(payment.source == .manual)
        #expect(payment.otherDescription == (method == .other ? "Mobile wallet" : nil))
        #expect(payment.reference == "Ref 42")
        #expect(payment.note == "Office only")
        #expect(payment.invoice === invoice)
    }

    @Test func rejectsDuplicatePaymentEvidence() throws {
        let graph = try InvoiceActionGraph.make(status: .paid)
        #expect(throws: InvoicePaymentError.invoiceAlreadyPaid) {
            try InvoicePaymentUseCase.recordPayment(
                invoiceID: graph.invoiceID,
                method: .cash,
                receivedAt: .now,
                in: graph.context
            )
        }
        let invoice = try #require(graph.context.model(for: graph.invoiceID) as? Invoice)
        #expect(invoice.payments.count == 1)
    }

    @Test func otherRequiresDescriptionAndOtherMethodsRejectIt() throws {
        let first = try InvoiceActionGraph.make()
        #expect(throws: InvoicePaymentError.invalidOtherDescription) {
            try InvoicePaymentUseCase.recordPayment(
                invoiceID: first.invoiceID,
                method: .other,
                receivedAt: .now,
                otherDescription: "  ",
                in: first.context
            )
        }
        let second = try InvoiceActionGraph.make()
        #expect(throws: InvoicePaymentError.invalidOtherDescription) {
            try InvoicePaymentUseCase.recordPayment(
                invoiceID: second.invoiceID,
                method: .cash,
                receivedAt: .now,
                otherDescription: "Wallet",
                in: second.context
            )
        }
        let firstInvoice = try #require(first.context.model(for: first.invoiceID) as? Invoice)
        let secondInvoice = try #require(second.context.model(for: second.invoiceID) as? Invoice)
        #expect(firstInvoice.statusRawValue == InvoiceStatus.unpaid.rawValue)
        #expect(firstInvoice.payments.isEmpty)
        #expect(secondInvoice.statusRawValue == InvoiceStatus.unpaid.rawValue)
        #expect(secondInvoice.payments.isEmpty)
    }

    @Test(arguments: [(Int64(12_499), "USD"), (Int64(12_500), "EUR"), (Int64(-1), "USD")])
    func aggregateValidationRejectsMismatchedAmountOrCurrency(
        _ input: (amount: Int64, currency: String)
    ) throws {
        let graph = try InvoiceActionGraph.make()
        let invoice = try #require(graph.context.model(for: graph.invoiceID) as? Invoice)
        let payment = Payment(
            amountMinorUnits: input.amount,
            currencyCode: input.currency,
            receivedAt: .now,
            method: .cash,
            invoice: invoice
        )
        try invoice.recordCompletedPayment(payment)

        #expect(throws: InvoiceDomainRuleError.invalidStatus) {
            _ = try InvoiceDomainRules.validatedStatus(
                rawValue: invoice.statusRawValue,
                payments: invoice.payments,
                invoiceCurrencyCode: invoice.currencyCode,
                totalMinorUnits: 12_500
            )
        }
    }

    @Test func aggregateRejectsWrongInvoiceInverseAndDuplicateEvidence() throws {
        let first = try InvoiceActionGraph.make()
        let second = try InvoiceActionGraph.make()
        let firstInvoice = try #require(first.context.model(for: first.invoiceID) as? Invoice)
        let secondInvoice = try #require(second.context.model(for: second.invoiceID) as? Invoice)
        let wrongInvoicePayment = Payment(
            amountMinorUnits: 12_500,
            currencyCode: "USD",
            receivedAt: .now,
            method: .cash,
            invoice: secondInvoice
        )
        #expect(throws: InvoicePaymentError.invalidPaymentEvidence) {
            try firstInvoice.recordCompletedPayment(wrongInvoicePayment)
        }

        try InvoicePaymentUseCase.recordPayment(
            invoiceID: first.invoiceID,
            method: .cash,
            receivedAt: .now,
            in: first.context
        )
        _ = Payment(
            amountMinorUnits: 12_500,
            currencyCode: "USD",
            receivedAt: .now,
            method: .card,
            invoice: firstInvoice
        )
        #expect(throws: InvoiceDomainRuleError.invalidStatus) {
            _ = try InvoiceDomainRules.validatedStatus(
                rawValue: firstInvoice.statusRawValue,
                payments: firstInvoice.payments,
                invoiceCurrencyCode: firstInvoice.currencyCode,
                totalMinorUnits: 12_500
            )
        }
    }

    @Test func markUnpaidDeletesEvidenceAndRestoresOutstandingState() throws {
        let graph = try InvoiceActionGraph.make(status: .paid)
        #expect(try graph.context.fetchCount(FetchDescriptor<Payment>()) == 1)

        try InvoicePaymentUseCase.markUnpaid(invoiceID: graph.invoiceID, in: graph.context)

        let invoice = try #require(graph.context.model(for: graph.invoiceID) as? Invoice)
        #expect(invoice.statusRawValue == InvoiceStatus.unpaid.rawValue)
        #expect(invoice.payments.isEmpty)
        #expect(try graph.context.fetchCount(FetchDescriptor<Payment>()) == 0)
        #expect(throws: InvoicePaymentError.invoiceAlreadyUnpaid) {
            try InvoicePaymentUseCase.markUnpaid(invoiceID: graph.invoiceID, in: graph.context)
        }
    }
}
