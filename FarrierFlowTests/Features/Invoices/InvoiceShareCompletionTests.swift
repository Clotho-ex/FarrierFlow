import Foundation
import Testing
@testable import FarrierFlow

@Suite("Invoice share completion")
@MainActor
struct InvoiceShareCompletionTests {
    @Test
    func openingOrCancellingShareDoesNotEmitButCompletedActivityDoes() {
        let analytics = AnalyticsSpy()
        var cleanupCount = 0

        InvoiceShareCompletion.handle(
            didComplete: false,
            analyticsClient: analytics,
            cleanup: { cleanupCount += 1 }
        )
        #expect(analytics.events.isEmpty)
        #expect(cleanupCount == 1)

        InvoiceShareCompletion.handle(
            didComplete: true,
            analyticsClient: analytics,
            cleanup: { cleanupCount += 1 }
        )
        #expect(analytics.events == [.invoiceShared])
        #expect(cleanupCount == 2)
    }
}
