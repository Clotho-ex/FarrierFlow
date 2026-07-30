import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Invoice domain rules", .serialized)
@MainActor
struct InvoiceDomainRulesTests {
    @Test(arguments: [
        (Int64(1), "0001"),
        (Int64(42), "0042"),
        (Int64(9_999), "9999"),
        (Int64(10_000), "10000"),
    ])
    func formatsPositiveInvoiceNumbersWithoutTruncation(
        number: Int64,
        expected: String
    ) throws {
        #expect(try InvoiceDomainRules.formattedNumber(number) == expected)
    }

    @Test(arguments: [Int64.min, -1, 0])
    func rejectsNonpositiveInvoiceNumbers(_ number: Int64) {
        #expect(throws: InvoiceDomainRuleError.invalidNumber) {
            _ = try InvoiceDomainRules.formattedNumber(number)
        }
    }

    @Test
    func validatesOnlySupportedStatusAndPaymentDatePairs() throws {
        let paymentDate = Date(timeIntervalSinceReferenceDate: 500)

        #expect(try InvoiceDomainRules.validatedStatus(
            rawValue: "unpaid",
            paidAt: nil
        ) == .unpaid)
        #expect(try InvoiceDomainRules.validatedStatus(
            rawValue: "paid",
            paidAt: paymentDate
        ) == .paid)

        #expect(throws: InvoiceDomainRuleError.invalidStatus) {
            _ = try InvoiceDomainRules.validatedStatus(
                rawValue: "unpaid",
                paidAt: paymentDate
            )
        }
        #expect(throws: InvoiceDomainRuleError.invalidStatus) {
            _ = try InvoiceDomainRules.validatedStatus(
                rawValue: "paid",
                paidAt: nil
            )
        }
        #expect(throws: InvoiceDomainRuleError.invalidStatus) {
            _ = try InvoiceDomainRules.validatedStatus(
                rawValue: "sent",
                paidAt: nil
            )
        }
    }

    @Test
    func checkedTotalRejectsNegativeAmountsAndOverflow() throws {
        #expect(try InvoiceDomainRules.checkedTotal([0, 12_500, 7_500]) == 20_000)
        #expect(throws: CheckedMoneyTotalError.negativeAmount) {
            _ = try InvoiceDomainRules.checkedTotal([1, -1])
        }
        #expect(throws: CheckedMoneyTotalError.overflow) {
            _ = try InvoiceDomainRules.checkedTotal([Int64.max, 1])
        }
    }

    @Test
    func anyBilledWorkItemLocksTheWholeSourceVisit() throws {
        let graph = try makeMixedClientInvoiceGraph()

        #expect(InvoiceDomainRules.isCorrectionLocked(graph.visit))

        graph.context.delete(graph.lineItem)
        graph.workItem.invoiceLineItem = nil
        #expect(!InvoiceDomainRules.isCorrectionLocked(graph.visit))
    }

    @Test
    func orderingUsesVisitThenLineSnapshotContract() throws {
        let graph = try makeMixedClientInvoiceGraph()
        let laterVisit = InvoiceVisit(
            visitDateSnapshot: Date(timeIntervalSinceReferenceDate: 300),
            serviceLocationNameSnapshot: "Alpha Farm",
            invoice: graph.invoice,
            sourceVisit: graph.visit
        )
        let earlierVisit = InvoiceVisit(
            visitDateSnapshot: Date(timeIntervalSinceReferenceDate: 100),
            serviceLocationNameSnapshot: "Zulu Farm",
            invoice: graph.invoice,
            sourceVisit: graph.visit
        )
        graph.context.insert(laterVisit)
        graph.context.insert(earlierVisit)

        let secondLine = InvoiceLineItem(
            horseNameSnapshot: "Atlas",
            serviceNameSnapshot: "Trim",
            amountMinorUnits: 5_000,
            invoiceVisit: graph.invoiceVisit,
            sourceWorkItem: graph.workItem
        )
        let thirdLine = InvoiceLineItem(
            horseNameSnapshot: "Milo",
            serviceNameSnapshot: "Front Shoes",
            amountMinorUnits: 9_000,
            invoiceVisit: graph.invoiceVisit,
            sourceWorkItem: graph.workItem
        )
        graph.context.insert(secondLine)
        graph.context.insert(thirdLine)

        #expect(
            InvoiceDomainRules.orderedVisits(
                [laterVisit, graph.invoiceVisit, earlierVisit],
                locale: Locale(identifier: "en_US")
            ).map(\.visitDateSnapshot) == [
                Date(timeIntervalSinceReferenceDate: 100),
                Date(timeIntervalSinceReferenceDate: 200),
                Date(timeIntervalSinceReferenceDate: 300),
            ]
        )
        #expect(
            InvoiceDomainRules.orderedLineItems(
                [thirdLine, graph.lineItem, secondLine],
                locale: Locale(identifier: "en_US")
            ).map {
                [
                    $0.horseNameSnapshot,
                    $0.serviceNameSnapshot,
                    String($0.amountMinorUnits),
                ]
            }
                == [
                    ["Atlas", "Trim", "5000"],
                    ["Milo", "Front Shoes", "9000"],
                    ["Milo", "Trim", "7500"],
                ]
        )
    }

    private func makeMixedClientInvoiceGraph() throws -> (
        container: ModelContainer,
        context: ModelContext,
        visit: Visit,
        workItem: WorkItem,
        invoice: Invoice,
        invoiceVisit: InvoiceVisit,
        lineItem: InvoiceLineItem
    ) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: [horse],
            in: context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 200),
            completedAt: Date(timeIntervalSinceReferenceDate: 250),
            appointment: appointment,
            in: context
        )
        let visitHorse = try #require(visit.visitHorses.first)
        visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
        let service = ModelFixtures.makeService(
            name: "Trim",
            defaultAmountMinorUnits: 7_500,
            in: context
        )
        let workItem = ModelFixtures.makeWorkItem(
            service: service,
            visitHorse: visitHorse,
            in: context
        )
        let profile = BusinessProfile(name: "Alex Carter Farrier")
        context.insert(profile)
        let invoice = Invoice(
            number: 1,
            invoiceDate: Date(timeIntervalSinceReferenceDate: 300),
            clientNameSnapshot: client.name,
            businessNameSnapshot: profile.name,
            client: client
        )
        context.insert(invoice)
        client.invoices.append(invoice)
        let invoiceVisit = InvoiceVisit(
            visitDateSnapshot: visit.startedAt,
            serviceLocationNameSnapshot: visit.serviceLocationNameSnapshot,
            invoice: invoice,
            sourceVisit: visit
        )
        context.insert(invoiceVisit)
        invoice.invoiceVisits.append(invoiceVisit)
        visit.invoiceVisits.append(invoiceVisit)
        let lineItem = InvoiceLineItem(
            horseNameSnapshot: horse.name,
            serviceNameSnapshot: workItem.serviceNameSnapshot,
            amountMinorUnits: workItem.amountMinorUnits,
            invoiceVisit: invoiceVisit,
            sourceWorkItem: workItem
        )
        context.insert(lineItem)
        invoiceVisit.lineItems.append(lineItem)
        workItem.invoiceLineItem = lineItem
        return (container, context, visit, workItem, invoice, invoiceVisit, lineItem)
    }
}
