import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Today model")
@MainActor
struct TodayModelTests {
    @Test
    func remainingLabelTracksStartTimeWithoutRemovingOrChangingUnfinishedAppointments() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        _ = ModelFixtures.makeBusinessProfile(in: context)
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let day = Calendar.current.startOfDay(for: .now)
        let featuredStart = day.addingTimeInterval(12 * 3_600)
        let groupedStart = day.addingTimeInterval(16 * 3_600)
        for start in [featuredStart, groupedStart, groupedStart] {
            _ = ModelFixtures.makeAppointment(startDate: start, barn: barn, horses: [horse], in: context)
        }
        try DomainGraphValidator.save(context)
        let model = TodayModel()
        model.load(in: context, now: featuredStart, calendar: .current)
        let originalStops = model.remainingStops
        guard case .openAppointment(let featured) = model.primaryAction else {
            Issue.record("Expected a featured appointment")
            return
        }
        #expect(String(localized: featured.heading(at: featuredStart.addingTimeInterval(-1))) == "Next Appointment")
        #expect(String(localized: featured.heading(at: featuredStart)) == "Due Now")
        #expect(String(localized: featured.heading(at: groupedStart)) == "Due Now")

        #expect(String(localized: model.remainingSectionTitle(at: groupedStart.addingTimeInterval(-1))) == "Later Today")
        #expect(String(localized: model.remainingSectionTitle(at: groupedStart)) == "Remaining Today")
        #expect(String(localized: model.remainingSectionTitle(at: groupedStart.addingTimeInterval(1))) == "Remaining Today")
        #expect(model.remainingStops == originalStops)
        #expect(!context.hasChanges)

        model.load(in: context, now: groupedStart.addingTimeInterval(3_600), calendar: .current)
        #expect(model.remainingStops == originalStops)
        #expect(model.remainingStops.first?.appointments.count == 2)
        let appointments = try context.fetch(FetchDescriptor<Appointment>())
        #expect(appointments.count == 3)
        #expect(appointments.allSatisfy { $0.visit == nil })
        #expect(model.remainingStops.allSatisfy { $0.id.state == .scheduled })
    }

    @Test
    func horseCountsUseLocalizedSingularAndPlural() {
        #expect(String(localized: "\(1) horses", locale: Locale(identifier: "en_US")) == "1 horse")
        #expect(String(localized: "\(2) horses", locale: Locale(identifier: "en_US")) == "2 horses")
    }

    @Test
    func groupsExactBarnTimeAndStateWhilePreservingEveryAppointment() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        _ = ModelFixtures.makeBusinessProfile(in: context)
        let client = Client(name: "Alex")
        let barn = Barn(name: "The Old Barn")
        let lookalike = Barn(name: "The Old Barn")
        context.insert(client)
        context.insert(barn)
        context.insert(lookalike)
        let first = Horse(name: "Thunder", client: client, currentBarn: barn)
        let second = Horse(name: "Peanut", client: client, currentBarn: barn)
        let third = Horse(name: "Thunder", client: client, currentBarn: lookalike)
        for horse in [first, second, third] {
            context.insert(horse)
            client.horses.append(horse)
            horse.currentBarn?.horses.append(horse)
        }
        let now = Calendar.current.startOfDay(for: .now).addingTimeInterval(12 * 3_600)
        let appointments = [
            ModelFixtures.makeAppointment(startDate: now, barn: barn, horses: [first], in: context),
            ModelFixtures.makeAppointment(startDate: now, barn: barn, horses: [second], in: context),
            ModelFixtures.makeAppointment(startDate: now, barn: barn, horses: [first], in: context),
            ModelFixtures.makeAppointment(startDate: now, barn: lookalike, horses: [third], in: context),
            ModelFixtures.makeAppointment(startDate: now.addingTimeInterval(60), barn: barn, horses: [first], in: context),
        ]
        try DomainGraphValidator.save(context)
        let model = TodayModel()
        model.load(in: context, now: now, calendar: .current)
        let stops = [model.featuredStop].compactMap { $0 } + model.remainingStops
        #expect(stops.count == 3)
        #expect(Set(stops.flatMap(\.appointments).map(\.id)) == Set(appointments.map(\.persistentModelID)))
        let grouped = try #require(stops.first { $0.appointments.count == 3 })
        #expect(grouped.horseNames == ["Peanut", "Thunder"])
        #expect(try context.fetchCount(FetchDescriptor<Appointment>()) == 5)
        #expect(model.remainingStops.allSatisfy { $0.id != model.featuredStop?.id })
    }

    @Test
    func featuredStopIncludesItsOtherAppointmentsWithoutRepeatingThemBelow() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        _ = ModelFixtures.makeBusinessProfile(in: context)
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let now = Date.now
        for _ in 0..<2 {
            _ = ModelFixtures.makeAppointment(startDate: now, barn: barn, horses: [horse], in: context)
        }
        try DomainGraphValidator.save(context)
        let model = TodayModel()
        model.load(in: context, now: now, calendar: .current)
        #expect(model.featuredStop?.appointments.count == 2)
        #expect(model.featuredStop?.horseNames == ["Milo"])
        #expect(model.remainingStops.isEmpty)

        let appointment = try #require(context.fetch(FetchDescriptor<Appointment>()).first)
        _ = ModelFixtures.makeVisit(startedAt: now, appointment: appointment, in: context)
        try DomainGraphValidator.save(context)
        model.load(in: context, now: now, calendar: .current)
        #expect(model.featuredStop == nil)
        #expect(model.remainingStops.count == 1)
        #expect(model.remainingStops.first?.appointments.count == 1)
        #expect(model.remainingStops.first?.appointments.first?.id != appointment.persistentModelID)
    }

    @Test
    func distinctHorseIdentitiesAndWorkStatesRemainVisible() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)
        let horse = ModelFixtures.makeHorse(client: client, barn: barn)
        context.insert(horse)
        let otherHorse = Horse(name: horse.name, client: client, currentBarn: barn)
        context.insert(otherHorse)
        let now = Date.now
        let first = ModelFixtures.makeAppointment(startDate: now, barn: barn, horses: [horse], in: context)
        let second = ModelFixtures.makeAppointment(startDate: now, barn: barn, horses: [otherHorse], in: context)
        func summary(_ appointment: Appointment, state: TodayAppointmentState) -> TodayAppointmentSummary {
            TodayAppointmentSummary(
                id: appointment.persistentModelID, startDate: now,
                serviceLocationID: barn.persistentModelID,
                serviceLocationName: barn.name, serviceLocationAddress: nil,
                horseNames: [horse.name], horseIDs: appointment.appointmentHorses.compactMap { $0.horse?.persistentModelID },
                state: state
            )
        }
        let scheduled = TodayStopSummary.grouped([summary(first, state: .scheduled), summary(second, state: .scheduled)])
        #expect(scheduled.count == 1)
        #expect(scheduled.first?.horseNames.count == 2)
        let mixed = TodayStopSummary.grouped([summary(first, state: .scheduled), summary(second, state: .completed)])
        #expect(mixed.count == 2)
    }

    @Test
    func initialLoadFailureUsesInlineRecoveryWithoutAlert() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let model = TodayModel()

        model.load(in: container.mainContext, now: .now, calendar: .current)

        #expect(model.loadState == .failed)
        #expect(model.alert == nil)
    }

    @Test
    func usesHalfOpenLocalDayAndPromotesOnlyTheFirstAppointment() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let now = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)
        ))
        let interval = try #require(calendar.dateInterval(of: .day, for: now))
        _ = ModelFixtures.makeBusinessProfile(in: context)
        let barn = Barn(name: "North Field")
        let client = Client(name: "Alex")
        context.insert(barn)
        context.insert(client)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        for date in [
            interval.start.addingTimeInterval(-1),
            interval.start,
            interval.start.addingTimeInterval(3_600),
            interval.end,
        ] {
            _ = ModelFixtures.makeAppointment(
                startDate: date,
                barn: barn,
                horses: [horse],
                in: context
            )
        }
        try DomainGraphValidator.save(context)

        let model = TodayModel()
        model.load(in: context, now: now, calendar: calendar)

        guard case .openAppointment(let promoted) = model.primaryAction else {
            Issue.record("Expected the first current-day appointment")
            return
        }
        #expect(promoted.startDate == interval.start)
        #expect(model.remainingAppointments.map(\.startDate) == [
            interval.start.addingTimeInterval(3_600),
        ])
    }

    @Test
    func activeVisitOutranksAndRemovesItsAppointmentFromTheWorkline() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let barn = Barn(name: "North Field")
        let client = Client(name: "Alex")
        context.insert(barn)
        context.insert(client)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        _ = ModelFixtures.makeBusinessProfile(in: context)
        let activeAppointment = ModelFixtures.makeAppointment(
            startDate: now,
            barn: barn,
            horses: [horse],
            in: context
        )
        let laterAppointment = ModelFixtures.makeAppointment(
            startDate: now.addingTimeInterval(3_600),
            barn: barn,
            horses: [horse],
            in: context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: now.addingTimeInterval(-600),
            appointment: activeAppointment,
            in: context
        )
        visit.visitHorses[0].outcomeRawValue = VisitOutcome.serviced.rawValue
        _ = ModelFixtures.makeWorkItem(
            service: ModelFixtures.makeService(in: context),
            visitHorse: visit.visitHorses[0],
            in: context
        )
        try DomainGraphValidator.save(context)

        let model = TodayModel()
        model.load(in: context, now: now, calendar: .current)

        guard case .resumeVisit(let summary) = model.primaryAction else {
            Issue.record("Expected active Visit to rank first")
            return
        }
        #expect(summary.id == visit.persistentModelID)
        #expect(summary.resolvedHorseCount == 1)
        #expect(summary.totalHorseCount == 1)
        #expect(model.remainingAppointments.map(\.id) == [laterAppointment.persistentModelID])
    }

    @Test
    func remainingAppointmentsExposeTheirVisitState() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let calendar = Calendar(identifier: .gregorian)
        let day = calendar.startOfDay(for: .now)
        let firstStart = try #require(calendar.date(byAdding: .hour, value: 8, to: day))
        let secondStart = try #require(calendar.date(byAdding: .hour, value: 9, to: day))
        let completedStart = try #require(calendar.date(byAdding: .hour, value: 10, to: day))
        let now = try #require(calendar.date(byAdding: .hour, value: 12, to: day))
        _ = ModelFixtures.makeBusinessProfile(in: context)
        let barn = Barn(name: "North Field")
        let client = Client(name: "Alex")
        context.insert(barn)
        context.insert(client)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)

        let promotedAppointment = ModelFixtures.makeAppointment(
            startDate: firstStart,
            barn: barn,
            horses: [horse],
            in: context
        )
        _ = ModelFixtures.makeVisit(
            startedAt: firstStart,
            appointment: promotedAppointment,
            in: context
        )

        let activeAppointment = ModelFixtures.makeAppointment(
            startDate: secondStart,
            barn: barn,
            horses: [horse],
            in: context
        )
        _ = ModelFixtures.makeVisit(
            startedAt: secondStart,
            appointment: activeAppointment,
            in: context
        )

        let completedAppointment = ModelFixtures.makeAppointment(
            startDate: completedStart,
            barn: barn,
            horses: [horse],
            in: context
        )
        let completedVisit = ModelFixtures.makeVisit(
            startedAt: completedStart,
            completedAt: completedStart.addingTimeInterval(1_800),
            appointment: completedAppointment,
            in: context
        )
        completedVisit.visitHorses[0].outcomeRawValue = VisitOutcome.serviced.rawValue
        _ = ModelFixtures.makeWorkItem(
            service: ModelFixtures.makeService(in: context),
            visitHorse: completedVisit.visitHorses[0],
            in: context
        )
        try DomainGraphValidator.save(context)

        let model = TodayModel()
        model.load(in: context, now: now, calendar: calendar)

        let stateByAppointment = Dictionary(
            uniqueKeysWithValues: model.remainingAppointments.map { ($0.id, $0.state) }
        )
        #expect(stateByAppointment[activeAppointment.persistentModelID] == .inProgress)
        #expect(stateByAppointment[completedAppointment.persistentModelID] == .completed)
    }

    @Test
    func firstClientOutranksContextualServiceAndLocationSetup() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        _ = ModelFixtures.makeBusinessProfile(in: context)
        try DomainGraphValidator.save(context)
        let model = TodayModel()

        model.load(in: context, now: .now, calendar: .current)
        #expect(model.primaryAction == .addClient)

        let client = Client(name: "Alex")
        context.insert(client)
        try DomainGraphValidator.save(context)
        model.load(in: context, now: .now, calendar: .current)
        #expect(model.primaryAction == .addHorse(client.persistentModelID))
    }

    @Test
    func invoiceCandidateCarriesTheExactOldestEligibleVisit() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        _ = ModelFixtures.makeBusinessProfile(in: context)
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        let service = ModelFixtures.makeService(in: context)
        let firstStart = Date(timeIntervalSinceReferenceDate: 100)
        let secondStart = Date(timeIntervalSinceReferenceDate: 200)
        let firstVisit = ModelFixtures.makeVisit(
            startedAt: firstStart,
            completedAt: firstStart.addingTimeInterval(50),
            appointment: ModelFixtures.makeAppointment(
                startDate: firstStart,
                barn: barn,
                horses: [horse],
                in: context
            ),
            in: context
        )
        let secondVisit = ModelFixtures.makeVisit(
            startedAt: secondStart,
            completedAt: secondStart.addingTimeInterval(50),
            appointment: ModelFixtures.makeAppointment(
                startDate: secondStart,
                barn: barn,
                horses: [horse],
                in: context
            ),
            in: context
        )
        for visit in [firstVisit, secondVisit] {
            visit.visitHorses[0].outcomeRawValue = VisitOutcome.serviced.rawValue
            _ = ModelFixtures.makeWorkItem(
                service: service,
                visitHorse: visit.visitHorses[0],
                in: context
            )
        }
        try DomainGraphValidator.save(context)
        let model = TodayModel()

        model.load(in: context, now: .now, calendar: .current)

        guard case .createInvoice(let candidate) = model.primaryAction else {
            Issue.record("Expected contextual Invoice creation")
            return
        }
        #expect(candidate.clientID == client.persistentModelID)
        #expect(candidate.visitID == firstVisit.persistentModelID)
        #expect(candidate.workDate == firstStart)
    }

    @Test
    func invalidUnpaidInvoicePaymentEvidenceFailsTheTodayLoad() throws {
        let graph = try InvoiceActionGraph.make()
        let invoice = try #require(graph.context.model(for: graph.invoiceID) as? Invoice)
        let workItem = try #require(graph.context.model(for: graph.workItemID) as? WorkItem)
        graph.context.insert(Payment(
            amountMinorUnits: workItem.amountMinorUnits,
            currencyCode: "USD",
            receivedAt: .now,
            method: .cash,
            invoice: invoice
        ))
        try graph.context.save()
        #expect(invoice.statusRawValue == InvoiceStatus.unpaid.rawValue)
        #expect(invoice.payments.count == 1)

        let model = TodayModel()
        model.load(in: graph.context, now: .now, calendar: .current)

        #expect(model.loadState == .failed)
        #expect(model.primaryAction == .scheduleAppointment)
    }

    @Test
    func horseSummaryKeepsShortListsAndCondensesLongLists() {
        let shortSummary = TodayHorseSummary(horseNames: ["Iris", "Milo"])
        #expect(shortSummary.visibleHorseNames == ["Iris", "Milo"])
        #expect(shortSummary.remainingHorseCount == 0)

        let longSummary = TodayHorseSummary(
            horseNames: ["Iris", "Milo", "Nova", "Otis", "Poppy"]
        )
        #expect(longSummary.visibleHorseNames == ["Iris", "Milo"])
        #expect(longSummary.remainingHorseCount == 3)
    }

    @Test
    func horseSummaryUsesSingularCopyForOneRemainingHorse() {
        let summary = String(
            localized: "\("Atlas and Beacon"), and \(1) more horses",
            locale: Locale(identifier: "en_US"),
            comment: "A shortened horse list followed by the number of additional horses."
        )

        #expect(summary == "Atlas and Beacon, and 1 more horse")
    }
}
