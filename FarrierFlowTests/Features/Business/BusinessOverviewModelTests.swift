import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Business overview", .serialized)
@MainActor
struct BusinessOverviewModelTests {
    private let now = Date(timeIntervalSince1970: 1_792_065_600) // October 15, 2026, 12:00 UTC.
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return value
    }
    private let locale = Locale(identifier: "en_US")

    @Test func unpaidSnapshotsRespectCurrencyAndExcludeFullPayments() throws {
        let fixture = try Fixture()
        _ = try fixture.invoice(number: 1, amount: 15_000)
        let paid = try fixture.invoice(number: 2, amount: 5_000)
        _ = try fixture.invoice(number: 3, amount: 3_500)
        try DomainGraphValidator.save(fixture.context)
        try InvoicePaymentUseCase.recordPayment(invoiceID: paid.persistentModelID, method: .cash, receivedAt: now, in: fixture.context)
        fixture.service.defaultAmountMinorUnits = 99_000
        try DomainGraphValidator.save(fixture.context)
        try RecordDeletionRules.delete(fixture.client, in: fixture.context)

        let model = BusinessOverviewModel()
        load(model, fixture)
        let summary = try #require(model.summary)
        #expect(!model.loadFailed)
        #expect(summary.outstandingMinorUnits == 18_500)
        #expect(summary.unpaidInvoiceCount == 2)
        #expect(summary.currencyCode == "GBP")
        #expect(MoneyFormatter.currency(minorUnits: summary.outstandingMinorUnits, currencyCode: summary.currencyCode, locale: locale) == "£185.00")

        let list = InvoiceListModel()
        list.load(in: fixture.context, filter: .unpaid)
        #expect(list.summaries.count == 2)
        #expect(list.summaries.allSatisfy { $0.status == .unpaid })
        #expect(!list.summaries.contains { $0.id == paid.persistentModelID })
        list.load(in: fixture.context)
        #expect(list.summaries.count == 3)
    }

    @Test func completedVisitsUseCompletionMonthAndCountEachVisitOnce() throws {
        let fixture = try Fixture()
        let month = try #require(calendar.dateInterval(of: .month, for: now))
        let crossing = fixture.visit(start: month.start.addingTimeInterval(-600), completed: month.start)
        let multipleHorses = fixture.visit(start: now.addingTimeInterval(-600), completed: now, horses: 2)
        let lastMoment = fixture.visit(start: month.end.addingTimeInterval(-600), completed: month.end.addingTimeInterval(-1))
        _ = fixture.visit(start: month.start.addingTimeInterval(-600), completed: month.start.addingTimeInterval(-1))
        _ = fixture.visit(start: month.end.addingTimeInterval(-600), completed: month.end)
        _ = fixture.visit(start: now, completed: nil)
        try DomainGraphValidator.save(fixture.context)

        let model = BusinessOverviewModel()
        load(model, fixture)
        #expect(model.summary?.completedVisitCount == 3)
        let list = CompletedVisitListModel()
        list.load(in: fixture.context, during: month, locale: locale)
        #expect(!list.loadFailed)
        #expect(list.visits.map(\.id) == [lastMoment.persistentModelID, multipleHorses.persistentModelID, crossing.persistentModelID])
        #expect(list.visits[1].horseNames.count == 2)
    }

    @Test func monthBoundaryUsesTheBusinessScreensLocalCalendar() throws {
        let fixture = try Fixture()
        var local = calendar
        local.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let month = try #require(local.dateInterval(of: .month, for: now))
        _ = fixture.visit(start: month.start.addingTimeInterval(-600), completed: month.start.addingTimeInterval(-1))
        _ = fixture.visit(start: month.start.addingTimeInterval(-600), completed: month.start)
        try DomainGraphValidator.save(fixture.context)
        let model = BusinessOverviewModel()
        model.load(in: fixture.context, now: now, calendar: local, locale: locale)
        #expect(model.summary?.completedVisitCount == 1)
        #expect(model.summary?.month == month)
    }

    @Test func paymentsReversalsAndDeletionsRefreshFromOtherContexts() throws {
        let fixture = try Fixture()
        let invoice = try fixture.invoice(number: 1, amount: 12_500)
        let extraVisit = fixture.visit(start: now.addingTimeInterval(-600), completed: now)
        try DomainGraphValidator.save(fixture.context)
        let id = invoice.persistentModelID
        let visitID = extraVisit.persistentModelID
        let model = BusinessOverviewModel()
        load(model, fixture)
        #expect(model.summary?.outstandingMinorUnits == 12_500)
        #expect(model.summary?.completedVisitCount == 1)

        let editingContext = ModelContext(fixture.container)
        try InvoicePaymentUseCase.recordPayment(invoiceID: id, method: .bankTransfer, receivedAt: now, in: editingContext)
        load(model, fixture)
        #expect(model.summary?.outstandingMinorUnits == 0)
        #expect(model.summary?.unpaidInvoiceCount == 0)
        try InvoicePaymentUseCase.markUnpaid(invoiceID: id, in: editingContext)
        load(model, fixture)
        #expect(model.summary?.outstandingMinorUnits == 12_500)
        let visit = try #require(try editingContext.existingModel(Visit.self, for: visitID))
        let month = try #require(calendar.dateInterval(of: .month, for: now))
        visit.startedAt = month.start.addingTimeInterval(-600)
        visit.completedAt = month.start.addingTimeInterval(-1)
        try DomainGraphValidator.save(editingContext)
        load(model, fixture)
        #expect(model.summary?.completedVisitCount == 0)
        visit.startedAt = now.addingTimeInterval(-600)
        visit.completedAt = now
        try DomainGraphValidator.save(editingContext)
        load(model, fixture)
        #expect(model.summary?.completedVisitCount == 1)
        try InvoiceDeletionUseCase.delete(invoiceID: id, in: editingContext)
        try RecordDeletionRules.delete(visit, in: editingContext)
        load(model, fixture)
        #expect(model.summary?.outstandingMinorUnits == 0)
        #expect(model.summary?.completedVisitCount == 0)
    }

    @Test func emptyBusinessHasNumericZeroAndNoInventedWork() throws {
        let fixture = try Fixture()
        try DomainGraphValidator.save(fixture.context)
        let model = BusinessOverviewModel()
        load(model, fixture)
        #expect(model.summary?.outstandingMinorUnits == 0)
        #expect(model.summary?.unpaidInvoiceCount == 0)
        #expect(model.summary?.completedVisitCount == 0)
        #expect(MoneyFormatter.currency(minorUnits: 0, currencyCode: "GBP", locale: locale, showsZeroAsComplimentary: false) == "£0.00")
        #expect(MoneyFormatter.currency(minorUnits: 0, currencyCode: "GBP", locale: locale) == "Complimentary")
    }

    @Test func corruptCurrencyClearsPreviousTotalsInsteadOfCombiningMoney() throws {
        let fixture = try Fixture()
        _ = try fixture.invoice(number: 1, amount: 12_500)
        try DomainGraphValidator.save(fixture.context)
        let model = BusinessOverviewModel()
        load(model, fixture)
        #expect(model.summary != nil)
        fixture.profile.currencyCode = "USD"
        try fixture.context.save() // Simulate invalid imported persistence without weakening production validation.
        load(model, fixture)
        #expect(model.summary == nil)
        #expect(model.loadFailed)
    }

    @Test func overflowDoesNotBecomeAFalseBalance() throws {
        let fixture = try Fixture()
        _ = try fixture.invoice(number: 1, amount: Int64.max)
        _ = try fixture.invoice(number: 2, amount: 1)
        try fixture.context.save()
        let model = BusinessOverviewModel()
        load(model, fixture)
        #expect(model.summary == nil)
        #expect(model.loadFailed)
    }

    private func load(_ model: BusinessOverviewModel, _ fixture: Fixture) {
        model.load(in: fixture.context, now: now, calendar: calendar, locale: locale)
    }

    @MainActor
    private struct Fixture {
        let container: ModelContainer
        var context: ModelContext { container.mainContext }
        let profile: BusinessProfile
        let client: Client
        let barn: Barn
        let service: Service
        let horses: [Horse]

        init() throws {
            container = try ModelContainerFactory.inMemoryTest()
            let context = container.mainContext
            profile = ModelFixtures.makeBusinessProfile(nextInvoiceNumber: 10, currencyCode: "GBP", in: context)
            client = Client(name: "Invoice Client")
            barn = Barn(name: "North Field")
            context.insert(client)
            context.insert(barn)
            service = ModelFixtures.makeService(currencyCode: "GBP", in: context)
            var createdHorses: [Horse] = []
            for name in ["Milo", "Scout"] {
                let horse = Horse(name: name, client: client, currentBarn: barn)
                context.insert(horse)
                client.horses.append(horse)
                barn.horses.append(horse)
                createdHorses.append(horse)
            }
            horses = createdHorses
        }

        func visit(start: Date, completed: Date?, horses count: Int = 1) -> Visit {
            let appointment = ModelFixtures.makeAppointment(startDate: start, barn: barn, horses: Array(horses.prefix(count)), in: context)
            let visit = ModelFixtures.makeVisit(startedAt: start, completedAt: completed, appointment: appointment, in: context)
            for horse in visit.visitHorses { horse.outcomeRawValue = (completed == nil ? VisitOutcome.pending : .notServiced).rawValue }
            return visit
        }

        func invoice(number: Int64, amount: Int64) throws -> Invoice {
            // Deliberately outside the overview month; unpaid balances are not month-limited.
            let start = Date(timeIntervalSinceReferenceDate: 100)
            let visit = visit(start: start, completed: start.addingTimeInterval(60))
            let horse = try #require(visit.visitHorses.first)
            horse.outcomeRawValue = VisitOutcome.serviced.rawValue
            let work = ModelFixtures.makeWorkItem(service: service, visitHorse: horse, amountMinorUnits: amount, in: context)
            let invoice = ModelFixtures.makeInvoice(number: number, client: client, businessProfile: profile, in: context)
            let group = ModelFixtures.makeInvoiceVisit(invoice: invoice, sourceVisit: visit, in: context)
            _ = try ModelFixtures.makeInvoiceLineItem(invoiceVisit: group, sourceWorkItem: work, in: context)
            return invoice
        }
    }
}
