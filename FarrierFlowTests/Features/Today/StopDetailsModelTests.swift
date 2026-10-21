import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Stop details model")
@MainActor
struct StopDetailsModelTests {
    @Test
    func sharedEditorTimeChangeSplitsTheStopWithoutChangingAppointmentIdentities() throws {
        let fixture = try Fixture()
        let model = StopDetailsModel(stop: fixture.stop)
        model.load(in: fixture.container)
        let editor = AppointmentEditorModel(appointment: fixture.peanutAppointment)
        editor.load(in: fixture.context)
        editor.draft.startDate = fixture.start.addingTimeInterval(3_600)
        #expect(editor.save(in: fixture.context) == fixture.peanutAppointment.persistentModelID)
        model.load(in: fixture.container)
        #expect(model.stop?.horseNames == ["Thunder"])
        #expect(model.stop?.id.startDate == fixture.start)
        let today = TodayModel()
        today.load(in: fixture.context, now: fixture.start, calendar: .current)
        let stops = [today.featuredStop].compactMap { $0 } + today.remainingStops
        #expect(stops.count == 2)
        #expect(Set(stops.flatMap(\.appointments).map(\.id)) == fixture.ids)
        let schedule = ScheduleModel()
        schedule.load(in: fixture.context, now: fixture.start, calendar: .current)
        #expect(Set(schedule.sections.flatMap(\.appointments).map(\.persistentModelID)) == fixture.ids)
        #expect(schedule.sections.flatMap(\.appointments).last?.startDate == editor.draft.startDate)
    }

    @Test
    func loneStopFollowsSavedDateLocationAndHorseChanges() throws {
        let fixture = try Fixture()
        let single = TodayStopSummary(
            id: fixture.stop.id,
            appointments: [try TodayAppointmentSummary.project(fixture.peanutAppointment)]
        )
        let other = try #require(try fixture.context.existingModel(Appointment.self, for: fixture.thunderAppointment.persistentModelID))
        other.startDate = fixture.start.addingTimeInterval(-3_600)
        try DomainGraphValidator.save(fixture.context)
        let model = StopDetailsModel(stop: single)
        model.load(in: fixture.container)
        let editor = AppointmentEditorModel(appointment: fixture.peanutAppointment)
        editor.load(in: fixture.context)
        editor.selectBarn(fixture.otherBarn.persistentModelID, in: fixture.context)
        editor.toggleHorse(fixture.otherHorse.persistentModelID)
        editor.draft.startDate = fixture.start.addingTimeInterval(86_400)
        #expect(editor.save(in: fixture.context) == fixture.peanutAppointment.persistentModelID)
        model.load(in: fixture.container)
        #expect(model.stop?.id.startDate == editor.draft.startDate)
        #expect(model.stop?.id.serviceLocationID == fixture.otherBarn.persistentModelID)
        #expect(model.stop?.horseNames == ["Willow"])
        #expect(model.stop?.appointments.first?.serviceLocationAddress == "New address")
        #expect(model.stop?.appointments.first?.id == fixture.peanutAppointment.persistentModelID)
        #expect(try fixture.context.fetchCount(FetchDescriptor<Appointment>()) == 2)
        let today = TodayModel()
        today.load(in: fixture.context, now: fixture.start, calendar: .current)
        #expect(([today.featuredStop].compactMap { $0 } + today.remainingStops).flatMap(\.appointments).allSatisfy {
            $0.id != fixture.peanutAppointment.persistentModelID
        })
        let schedule = ScheduleModel()
        schedule.load(in: fixture.context, now: fixture.start, calendar: .current)
        #expect(schedule.sections.count == 2)
    }

    @Test
    func horseEditsAndVisitStateReloadFromSavedRelationships() throws {
        let fixture = try Fixture()
        let model = StopDetailsModel(stop: fixture.stop)
        let editor = AppointmentEditorModel(appointment: fixture.peanutAppointment)
        editor.load(in: fixture.context)
        let thunder = try #require(fixture.thunderAppointment.appointmentHorses.first?.horse)
        editor.toggleHorse(thunder.persistentModelID)
        #expect(editor.save(in: fixture.context) != nil)
        model.load(in: fixture.container)
        #expect(model.stop?.horseNames == ["Peanut", "Thunder"])
        #expect(model.stop?.appointments.first { $0.id == fixture.peanutAppointment.persistentModelID }?.horseNames == ["Peanut", "Thunder"])
        let visitID = try VisitStartUseCase.start(
            appointmentID: fixture.peanutAppointment.persistentModelID, now: fixture.start, in: fixture.container
        )
        model.load(in: fixture.container)
        #expect(model.stop?.appointments.map(\.id) == [fixture.thunderAppointment.persistentModelID])
        let fresh = ModelContext(fixture.container)
        let saved = try #require(try fresh.existingModel(Appointment.self, for: fixture.peanutAppointment.persistentModelID))
        #expect(saved.visit?.persistentModelID == visitID)
        let active = try TodayAppointmentSummary.project(saved)
        let activeModel = StopDetailsModel(stop: TodayStopSummary(
            id: .init(serviceLocationID: active.serviceLocationID, startDate: active.startDate, state: active.state),
            appointments: [active]
        ))
        activeModel.load(in: fixture.container)
        #expect(activeModel.stop?.id.state == .inProgress)
        #expect(activeModel.stop?.appointments.count == 1)
    }

    @Test
    func discardedDraftDoesNotChangeStopMembershipOrPersistedValues() throws {
        let fixture = try Fixture()
        let model = StopDetailsModel(stop: fixture.stop)
        let editor = AppointmentEditorModel(appointment: fixture.peanutAppointment)
        editor.load(in: fixture.context)
        editor.draft.startDate = fixture.start.addingTimeInterval(86_400)
        editor.selectBarn(fixture.otherBarn.persistentModelID, in: fixture.context)
        model.load(in: fixture.container)
        #expect(model.stop?.id == fixture.stop.id)
        #expect(model.stop?.appointments.count == 2)
        #expect(fixture.peanutAppointment.startDate == fixture.start)
        #expect(!fixture.context.hasChanges)
    }

    @MainActor
    private struct Fixture {
        let container: ModelContainer
        var context: ModelContext { container.mainContext }
        let start: Date
        let otherBarn: Barn
        let otherHorse: Horse
        let peanutAppointment: Appointment
        let thunderAppointment: Appointment
        let stop: TodayStopSummary
        var ids: Set<PersistentIdentifier> { [peanutAppointment.persistentModelID, thunderAppointment.persistentModelID] }

        init() throws {
            container = try ModelContainerFactory.inMemoryTest()
            let context = container.mainContext
            _ = ModelFixtures.makeBusinessProfile(in: context)
            start = Calendar.current.startOfDay(for: .now).addingTimeInterval(16 * 3_600)
            let client = Client(name: "Alex")
            let barn = Barn(name: "The Old Barn")
            otherBarn = Barn(name: "New Barn", address: "New address")
            context.insert(client)
            context.insert(barn)
            context.insert(otherBarn)
            let peanut = Horse(name: "Peanut", client: client, currentBarn: barn)
            let thunder = Horse(name: "Thunder", client: client, currentBarn: barn)
            otherHorse = Horse(name: "Willow", client: client, currentBarn: otherBarn)
            for horse in [peanut, thunder, otherHorse] {
                context.insert(horse)
                client.horses.append(horse)
                horse.currentBarn?.horses.append(horse)
            }
            peanutAppointment = ModelFixtures.makeAppointment(startDate: start, barn: barn, horses: [peanut], in: context)
            thunderAppointment = ModelFixtures.makeAppointment(startDate: start, barn: barn, horses: [thunder], in: context)
            try DomainGraphValidator.save(context)
            stop = try #require(TodayStopSummary.grouped([
                try TodayAppointmentSummary.project(peanutAppointment),
                try TodayAppointmentSummary.project(thunderAppointment),
            ]).first)
        }
    }
}
