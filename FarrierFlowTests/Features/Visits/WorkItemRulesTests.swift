import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("WorkItem draft rules")
struct WorkItemRulesTests {
    @Test
    @MainActor
    func rejectsDuplicateServicesForOneHorseDraft() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let service = Service(name: "Trim", defaultAmountMinorUnits: 7_500)
        context.insert(service)
        let serviceID = service.persistentModelID
        let first = WorkItemDraft(
            serviceID: serviceID,
            serviceNameSnapshot: "Trim",
            amountMinorUnits: 7_500
        )
        let second = WorkItemDraft(
            serviceID: serviceID,
            serviceNameSnapshot: "Trim",
            amountMinorUnits: 7_500
        )

        #expect(WorkItemRules.violation(in: [first, second]) == .duplicateService)
    }

    @Test
    @MainActor
    func subtotalUsesCheckedIntegerArithmetic() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let firstService = Service(name: "Trim", defaultAmountMinorUnits: 7_500)
        let secondService = Service(name: "Shoes", defaultAmountMinorUnits: 12_500)
        context.insert(firstService)
        context.insert(secondService)
        let workItems = [
            WorkItemDraft(
                serviceID: firstService.persistentModelID,
                serviceNameSnapshot: "Trim",
                amountMinorUnits: 7_500
            ),
            WorkItemDraft(
                serviceID: secondService.persistentModelID,
                serviceNameSnapshot: "Shoes",
                amountMinorUnits: 12_500
            ),
        ]

        #expect(try WorkItemRules.subtotal(for: workItems) == 20_000)

        let overflowing = WorkItemDraft(
            serviceID: secondService.persistentModelID,
            serviceNameSnapshot: "Shoes",
            amountMinorUnits: Int64.max
        )
        #expect(throws: WorkItemDraftViolation.subtotalOverflow) {
            try WorkItemRules.subtotal(for: [workItems[0], overflowing])
        }
    }
}
