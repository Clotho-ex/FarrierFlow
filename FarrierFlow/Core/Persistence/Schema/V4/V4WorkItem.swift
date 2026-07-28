import SwiftData

extension FarrierFlowSchemaV4 {
    @Model
    final class WorkItem {
        var serviceNameSnapshot: String
        var amountMinorUnits: Int64
        var currencyCode: String

        var service: Service?

        var visitHorse: VisitHorse?

        init(
            serviceNameSnapshot: String,
            amountMinorUnits: Int64,
            currencyCode: String = "USD",
            service: Service,
            visitHorse: VisitHorse
        ) {
            self.serviceNameSnapshot = serviceNameSnapshot
            self.amountMinorUnits = amountMinorUnits
            self.currencyCode = currencyCode
            self.service = service
            self.visitHorse = visitHorse
        }
    }
}
