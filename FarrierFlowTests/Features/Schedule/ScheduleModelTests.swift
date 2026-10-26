import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Schedule model")
@MainActor
struct ScheduleModelTests {
    @Test
    func excludesBeforeBoundaryAndGroupsChronologically() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
        let now = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 3, day: 8, hour: 15)
        ))
        let boundary = calendar.startOfDay(for: now)
        let barn = Barn(name: "North Field")
        let client = Client(name: "Alex")
        context.insert(barn)
        context.insert(client)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)
        for offset in [-1.0, 0, 3_600, 90_000] {
            _ = ModelFixtures.makeAppointment(
                startDate: boundary.addingTimeInterval(offset),
                barn: barn,
                horses: [horse],
                in: context
            )
        }
        try context.save()

        let model = ScheduleModel()
        model.load(in: context, now: now, calendar: calendar)

        #expect(model.sections.count == 2)
        #expect(model.sections.flatMap(\.appointments).count == 3)
        #expect(model.sections[0].appointments.map(\.startDate).isSorted())
        #expect(model.sections[0].dayStart == boundary)
    }
    @Test
    func freshVisitStateSeparatesTabsAndFiltersByActualCompletedServices() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        context.insert(horse)
        let planned = ModelFixtures.makeService(name: "Planned Trim", in: context)
        let performed = ModelFixtures.makeService(name: "Actual Work", in: context)
        let appointment = ModelFixtures.makeAppointment(startDate: now, barn: barn, horses: [horse], in: context)
        appointment.appointmentHorses.first?.plannedService = planned
        let future = ModelFixtures.makeAppointment(startDate: now.addingTimeInterval(86_400), barn: barn, horses: [horse], in: context)
        future.appointmentHorses.first?.plannedService = planned
        try DomainGraphValidator.save(context)
        let model = ScheduleModel()
        model.load(in: context, now: now, calendar: calendar)
        #expect(model.sections.flatMap(\.appointments).count == 2)
        #expect(appointment.visit == nil)

        let writer = ModelContext(container)
        let freshAppointment = try #require(try writer.existingModel(Appointment.self, for: appointment.persistentModelID))
        let visit = ModelFixtures.makeVisit(startedAt: now, completedAt: now.addingTimeInterval(1800), appointment: freshAppointment, in: writer)
        let member = try #require(visit.visitHorses.first)
        member.outcomeRawValue = VisitOutcome.serviced.rawValue
        let service = try #require(try writer.existingModel(Service.self, for: performed.persistentModelID))
        _ = ModelFixtures.makeWorkItem(service: service, visitHorse: member, in: writer)
        try DomainGraphValidator.save(writer)

        model.load(in: context, now: now, calendar: calendar, scope: .completed)
        let rows = model.sections.flatMap(\.appointments)
        #expect(rows.count == 1)
        #expect(rows.first?.summary.state == .completed)
        #expect(rows.first?.summary.plannedServices == nil)
        #expect(model.services.map(\.id) == [performed.persistentModelID])
        model.load(in: context, now: now, calendar: calendar, scope: .completed, serviceID: planned.persistentModelID)
        #expect(model.sections.isEmpty)
        model.load(in: context, now: now, calendar: calendar, scope: .completed, serviceID: performed.persistentModelID)
        #expect(model.sections.flatMap(\.appointments).count == 1)
        model.load(in: context, now: now, calendar: calendar, scope: .scheduled, serviceID: planned.persistentModelID)
        #expect(model.sections.flatMap(\.appointments).map(\.id) == [future.persistentModelID])
        #expect(model.sections.flatMap(\.appointments).first?.summary.state == .scheduled)
    }

}

private extension Array where Element: Comparable {
    func isSorted() -> Bool {
        zip(self, dropFirst()).allSatisfy(<=)
    }
}
