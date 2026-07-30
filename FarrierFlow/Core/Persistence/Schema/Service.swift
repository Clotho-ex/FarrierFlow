import SwiftData

extension FarrierFlowSchemaV1 {
    @Model
    final class Service {
        var name: String
        var defaultAmountMinorUnits: Int64
        var currencyCode: String
        var isArchived: Bool

        @Relationship(deleteRule: .deny, inverse: \Horse.defaultService)
        var horsesUsingAsDefault: [Horse] = []

        @Relationship(deleteRule: .deny, inverse: \WorkItem.service)
        var workItems: [WorkItem] = []

        init(
            name: String,
            defaultAmountMinorUnits: Int64,
            currencyCode: String = "USD",
            isArchived: Bool = false
        ) {
            self.name = name
            self.defaultAmountMinorUnits = defaultAmountMinorUnits
            self.currencyCode = currencyCode
            self.isArchived = isArchived
        }
    }
}
