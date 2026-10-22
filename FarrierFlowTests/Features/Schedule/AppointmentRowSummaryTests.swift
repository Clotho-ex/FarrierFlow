import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Schedule appointment row summary")
@MainActor
struct AppointmentRowSummaryTests {
    @Test
    func singleHorseShowsActualOwnerAndOnlyExplicitAppointmentPlan() throws {
        let fixture = try makeFixture(horseCount: 1)
        let usual = ModelFixtures.makeService(name: "Usual Shoeing", in: fixture.context)
        let plan = ModelFixtures.makeService(name: "Trim", in: fixture.context)
        fixture.horses[0].defaultService = usual
        let unplanned = AppointmentRowSummary(appointment: fixture.appointment)
        #expect(unplanned.horseDetail == "Horse 1 · John Doe")
        #expect(unplanned.plannedServices == nil)
        #expect(unplanned.state == .scheduled)
        fixture.appointment.appointmentHorses[0].plannedService = plan
        try DomainGraphValidator.save(fixture.context)
        let otherContext = ModelContext(fixture.container)
        let appointment = try #require(try otherContext.existingModel(Appointment.self, for: fixture.appointment.persistentModelID))
        #expect(AppointmentRowSummary(appointment: appointment).plannedServices == "Trim")
        #expect(appointment.appointmentHorses[0].horse?.defaultService?.name == "Usual Shoeing")
    }

    @Test
    func multipleHorsesStayBoundedAndPartialPlansRemainHonest() throws {
        let fixture = try makeFixture(horseCount: 10)
        let service = ModelFixtures.makeService(name: "Trim", in: fixture.context)
        fixture.appointment.appointmentHorses[0].plannedService = service
        let summary = AppointmentRowSummary(appointment: fixture.appointment)
        #expect(summary.horseDetail == "10 horses · John Doe")
        #expect(summary.plannedServices == "Trim · 1 of 10 horses")
        let otherClient = Client(name: "Casey")
        fixture.context.insert(otherClient)
        fixture.horses[0].client = otherClient
        #expect(AppointmentRowSummary(appointment: fixture.appointment).horseDetail == "10 horses · 2 clients")
    }

    @Test
    func repeatedServicesCollapseAndLongServiceListsHaveABoundedSummary() throws {
        let fixture = try makeFixture(horseCount: 5)
        let trim = ModelFixtures.makeService(name: "Trim", in: fixture.context)
        fixture.appointment.appointmentHorses.forEach { $0.plannedService = trim }
        #expect(AppointmentRowSummary(appointment: fixture.appointment).plannedServices == "Trim")
        for (index, membership) in fixture.appointment.appointmentHorses.enumerated() {
            membership.plannedService = ModelFixtures.makeService(name: "Service \(index + 1)", in: fixture.context)
        }
        #expect(AppointmentRowSummary(appointment: fixture.appointment).plannedServices == "Service 1, Service 2, and 3 more")
    }

    @Test
    func statusUsesVisitTruthRatherThanAppointmentTime() throws {
        let fixture = try makeFixture(horseCount: 1)
        fixture.appointment.startDate = .distantPast
        #expect(AppointmentRowSummary(appointment: fixture.appointment).state == .scheduled)
        let visit = ModelFixtures.makeVisit(appointment: fixture.appointment, in: fixture.context)
        #expect(AppointmentRowSummary(appointment: fixture.appointment).state == .inProgress)
        visit.completedAt = .now
        #expect(AppointmentRowSummary(appointment: fixture.appointment).state == .completed)
    }

    @Test
    func unavailableRelationshipsDoNotInventOwnerOrPlannedWork() throws {
        let fixture = try makeFixture(horseCount: 1)
        fixture.horses[0].client = nil
        #expect(AppointmentRowSummary(appointment: fixture.appointment).horseDetail == "Horse 1")
        fixture.appointment.appointmentHorses[0].horse = nil
        fixture.appointment.barn = nil
        let summary = AppointmentRowSummary(appointment: fixture.appointment)
        #expect(summary.horseDetail == "Horse unavailable")
        #expect(summary.barnName == "Service location unavailable")
        #expect(summary.plannedServices == nil)
    }

    private func makeFixture(horseCount: Int) throws -> (
        container: ModelContainer, context: ModelContext, appointment: Appointment, horses: [Horse]
    ) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "John Doe")
        let barn = Barn(name: "The Old Barn")
        context.insert(client)
        context.insert(barn)
        var horses: [Horse] = []
        for index in 1...horseCount {
            let horse = Horse(name: "Horse \(index)", client: client, currentBarn: barn)
            context.insert(horse)
            client.horses.append(horse)
            barn.horses.append(horse)
            horses.append(horse)
        }
        let appointment = ModelFixtures.makeAppointment(barn: barn, horses: horses, in: context)
        try DomainGraphValidator.save(context)
        return (container, context, appointment, horses)
    }
}
