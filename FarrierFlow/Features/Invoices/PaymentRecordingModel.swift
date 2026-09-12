import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class PaymentRecordingModel {
    let invoiceID: PersistentIdentifier
    var draft: PaymentRecordingDraft
    private(set) var didRecord = false
    var alert: FeatureAlert?

    var canConfirm: Bool {
        guard let method = draft.method else { return false }
        return method != .other || TextNormalization.required(draft.otherDescription) != nil
    }

    init(
        invoiceID: PersistentIdentifier,
        amountMinorUnits: Int64,
        currencyCode: String,
        now: Date = .now
    ) {
        self.invoiceID = invoiceID
        draft = PaymentRecordingDraft(
            amountMinorUnits: amountMinorUnits,
            currencyCode: currencyCode,
            receivedAt: now
        )
    }

    func confirm(
        in context: ModelContext,
        analyticsClient: any AnalyticsClient = NoOpAnalyticsClient()
    ) {
        guard let method = draft.method, canConfirm else {
            alert = FeatureAlert(
                title: "Payment Method Required",
                message: "Choose how this payment was received."
            )
            return
        }
        do {
            try InvoicePaymentUseCase.recordPayment(
                invoiceID: invoiceID,
                method: method,
                receivedAt: draft.receivedAt,
                otherDescription: draft.otherDescription,
                reference: draft.reference,
                note: draft.note,
                in: context
            )
            didRecord = true
            alert = nil
            analyticsClient.track(.invoiceMarkedPaid)
        } catch {
            alert = FeatureAlert(
                title: "Couldn’t Record Payment",
                message: "The invoice remains unpaid. Check the details and try again."
            )
        }
    }
}
