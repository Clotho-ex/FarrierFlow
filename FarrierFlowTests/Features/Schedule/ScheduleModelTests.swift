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
}

private extension Array where Element: Comparable {
    func isSorted() -> Bool {
        zip(self, dropFirst()).allSatisfy(<=)
    }
}
