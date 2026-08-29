import Foundation
import Testing
@testable import FarrierFlow

@Suite("Payment recording draft")
struct PaymentRecordingDraftTests {
    @Test(arguments: [
        PaymentMethod.cash,
        .bankTransfer,
        .card,
        .cheque,
    ])
    func selectingAStandardMethodClearsTheOtherDescription(_ method: PaymentMethod) {
        var draft = PaymentRecordingDraft(
            amountMinorUnits: 12_500,
            currencyCode: "USD",
            receivedAt: Date(timeIntervalSinceReferenceDate: 1_000)
        )
        draft.method = .other
        draft.otherDescription = "Mobile wallet"

        draft.method = method

        #expect(draft.otherDescription.isEmpty)
    }
}
