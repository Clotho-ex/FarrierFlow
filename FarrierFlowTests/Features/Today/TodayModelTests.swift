import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Today model")
@MainActor
struct TodayModelTests {
    @Test
    func usesHalfOpenLocalDayAndChronologicalOrder() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let now = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 11, day: 1, hour: 12)
        ))
        let interval = try #require(calendar.dateInterval(of: .day, for: now))
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
        try context.save()

        let model = TodayModel()
        model.load(in: context, now: now, calendar: calendar)

        #expect(model.appointments.map(\.startDate) == [
            interval.start,
            interval.start.addingTimeInterval(3_600),
        ])
    }
}
