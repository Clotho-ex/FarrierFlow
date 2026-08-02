import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Appointment editor model")
@MainActor
struct AppointmentEditorModelTests {
    private enum ForcedFetchFailure: Error {
        case unavailable
    }

    @Test
    func newDraftStartsAtTheNextHalfHour() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let now = try #require(calendar.date(
            from: DateComponents(
                year: 2026,
                month: 8,
                day: 2,
                hour: 10,
                minute: 7,
                second: 42
            )
        ))

        let editor = AppointmentEditorModel(now: now, calendar: calendar)
        let expected = try #require(calendar.date(
            from: DateComponents(
                year: 2026,
                month: 8,
                day: 2,
                hour: 10,
                minute: 30
            )
        ))

        #expect(editor.draft.startDate == expected)
    }

    @Test
    func newDraftAppliesOwnerDurationOnceAndPreservesTheUserOverride() throws {
        let fixture = try makeTwoHorseFixture()
        let profile = ModelFixtures.makeBusinessProfile(
            defaultAppointmentDurationMinutes: 45,
            in: fixture.context
        )
        try DomainGraphValidator.save(fixture.context)
        let editor = AppointmentEditorModel()

        editor.load(in: fixture.context)

        #expect(editor.draft.expectedDurationText == "45")
        #expect(editor.appliedOwnerDurationDefault)
        editor.draft.expectedDurationText = "60"
        profile.defaultAppointmentDurationMinutes = 90
        try DomainGraphValidator.save(fixture.context)

        editor.load(in: fixture.context)

        #expect(editor.draft.expectedDurationText == "60")
    }

    @Test
    func existingAppointmentIgnoresCurrentOwnerDurationDefault() throws {
        let fixture = try makeTwoHorseFixture()
        _ = ModelFixtures.makeBusinessProfile(
            defaultAppointmentDurationMinutes: 90,
            in: fixture.context
        )
        let appointment = ModelFixtures.makeAppointment(
            barn: fixture.barn,
            horses: fixture.horses,
            in: fixture.context
        )
        appointment.expectedDurationMinutes = 30
        try DomainGraphValidator.save(fixture.context)
        let editor = AppointmentEditorModel(appointment: appointment)

        editor.load(in: fixture.context)

        #expect(editor.draft.expectedDurationText == "30")
        #expect(!editor.appliedOwnerDurationDefault)
    }

    @Test
    func saveRequirementTracksTheFirstMissingAppointmentValue() throws {
        let fixture = try makeTwoHorseFixture()
        let editor = AppointmentEditorModel()

        editor.load(in: fixture.context)
        #expect(editor.saveRequirement == .serviceLocation)

        editor.selectBarn(fixture.barn.persistentModelID, in: fixture.context)
        #expect(editor.saveRequirement == .horse)

        editor.toggleHorse(fixture.horses[0].persistentModelID)
        #expect(editor.saveRequirement == nil)

        editor.draft.expectedDurationText = "0"
        #expect(editor.saveRequirement == .expectedDuration)
    }

    @Test
    func createsOneBarnStopForHorsesFromMultipleClients() throws {
        let fixture = try makeTwoHorseFixture()
        let editor = AppointmentEditorModel()
        editor.load(in: fixture.context)
        editor.selectBarn(fixture.barn.persistentModelID, in: fixture.context)
        editor.toggleHorse(fixture.horses[0].persistentModelID)
        editor.toggleHorse(fixture.horses[1].persistentModelID)

        let id = try #require(editor.save(in: fixture.context))
        let appointment = try #require(fixture.context.model(for: id) as? Appointment)
        #expect(appointment.appointmentHorses.count == 2)
        #expect(
            Set(appointment.appointmentHorses.compactMap(\.horse?.client?.name))
                == ["Alex", "Jordan"]
        )
        #expect(appointment.expectedDurationMinutes == nil)
    }

    @Test
    func changingBarnClearsIneligibleSelection() throws {
        let fixture = try makeTwoHorseFixture()
        let otherBarn = Barn(name: "South Field")
        fixture.context.insert(otherBarn)
        try fixture.context.save()
        let editor = AppointmentEditorModel()
        editor.load(in: fixture.context)
        editor.selectBarn(fixture.barn.persistentModelID, in: fixture.context)
        editor.toggleHorse(fixture.horses[0].persistentModelID)

        editor.selectBarn(otherBarn.persistentModelID, in: fixture.context)
        #expect(editor.draft.selectedHorseIDs.isEmpty)
    }

    @Test
    func loadPublishesRecords() throws {
        let fixture = try makeTwoHorseFixture()
        let editor = AppointmentEditorModel()
        editor.load(in: fixture.context)
        editor.selectBarn(fixture.barn.persistentModelID, in: fixture.context)

        #expect(editor.loadState == .loaded)
        #expect(editor.barns.map(\.name) == ["North Field"])
        #expect(Set(editor.eligibleHorses.map(\.name)) == ["Milo", "Scout"])
    }

    @Test
    func loadPublishesLegitimateEmptyResult() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let editor = AppointmentEditorModel()

        editor.load(in: container.mainContext)

        #expect(editor.loadState == .loaded)
        #expect(editor.barns.isEmpty)
        #expect(editor.eligibleHorses.isEmpty)
    }

    @Test
    func selectingCreatedServiceLocationPreservesDraftAndSelectsIt() throws {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let editor = AppointmentEditorModel()
        editor.load(in: context)
        editor.draft.notes = "Keep this appointment note"
        editor.draft.expectedDurationText = "45"
        let barn = Barn(name: "New Service Location")
        context.insert(barn)
        try context.save()

        editor.selectCreatedBarn(barn.persistentModelID, in: context)

        #expect(editor.loadState == .loaded)
        #expect(editor.draft.barnID == barn.persistentModelID)
        #expect(editor.draft.notes == "Keep this appointment note")
        #expect(editor.draft.expectedDurationText == "45")
        #expect(editor.saveRequirement == .horse)
    }

    @Test
    func selectingCreatedHorsePreservesDraftAndSelectsEligibleHorse() throws {
        let fixture = try makeTwoHorseFixture()
        let editor = AppointmentEditorModel()
        editor.load(in: fixture.context)
        editor.selectBarn(fixture.barn.persistentModelID, in: fixture.context)
        editor.draft.notes = "Keep this appointment note"
        let client = Client(name: "Casey")
        fixture.context.insert(client)
        let horse = Horse(
            name: "River",
            client: client,
            currentBarn: fixture.barn
        )
        fixture.context.insert(horse)
        client.horses.append(horse)
        fixture.barn.horses.append(horse)
        try fixture.context.save()

        editor.selectCreatedHorse(horse.persistentModelID, in: fixture.context)

        #expect(editor.loadState == .loaded)
        #expect(editor.draft.selectedHorseIDs == [horse.persistentModelID])
        #expect(editor.draft.notes == "Keep this appointment note")
        #expect(editor.saveRequirement == nil)
    }

    @Test
    func loadFailurePreservesRecordsAndDraft() throws {
        let fixture = try makeTwoHorseFixture()
        var shouldFail = false
        let editor = AppointmentEditorModel(
            barnFetcher: { context in
                if shouldFail { throw ForcedFetchFailure.unavailable }
                return try context.fetch(FetchDescriptor<Barn>())
            },
            horseFetcher: { context in
                if shouldFail { throw ForcedFetchFailure.unavailable }
                return try context.fetch(FetchDescriptor<Horse>())
            }
        )
        editor.load(in: fixture.context)
        editor.selectBarn(fixture.barn.persistentModelID, in: fixture.context)
        editor.toggleHorse(fixture.horses[0].persistentModelID)
        editor.draft.notes = "Preserve this note"

        shouldFail = true
        editor.load(in: fixture.context)

        #expect(editor.loadState == .failed)
        #expect(editor.barns.map(\.name) == ["North Field"])
        #expect(Set(editor.eligibleHorses.map(\.name)) == ["Milo", "Scout"])
        #expect(editor.draft.selectedHorseIDs == [fixture.horses[0].persistentModelID])
        #expect(editor.draft.notes == "Preserve this note")
    }

    @Test
    func visitLockedAppointmentLoadsAndSavesMetadataWithoutChoiceFetches() throws {
        let fixture = try makeTwoHorseFixture()
        let appointment = ModelFixtures.makeAppointment(
            startDate: Date(timeIntervalSinceReferenceDate: 100),
            barn: fixture.barn,
            horses: fixture.horses,
            in: fixture.context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: appointment,
            in: fixture.context
        )
        try DomainGraphValidator.save(fixture.context)

        let originalBarnID = try #require(appointment.barn?.persistentModelID)
        let originalHorseIDs = Set(
            appointment.appointmentHorses.compactMap(\.horse?.persistentModelID)
        )
        let originalVisitHorseIDs = Set(visit.visitHorses.map(\.persistentModelID))
        var barnFetchCount = 0
        var horseFetchCount = 0
        let editor = AppointmentEditorModel(
            appointment: appointment,
            barnFetcher: { _ in
                barnFetchCount += 1
                throw ForcedFetchFailure.unavailable
            },
            horseFetcher: { _ in
                horseFetchCount += 1
                throw ForcedFetchFailure.unavailable
            }
        )

        editor.load(in: fixture.context)

        #expect(editor.loadState == .loaded)
        #expect(editor.canSave)
        #expect(barnFetchCount == 0)
        #expect(horseFetchCount == 0)
        #expect(editor.lockedBarnName == "North Field")
        #expect(editor.lockedHorseNames == ["Milo", "Scout"])

        editor.draft.startDate = Date(timeIntervalSinceReferenceDate: 300)
        editor.draft.notes = "  Gate code changed  "
        editor.draft.expectedDurationText = "45"

        #expect(editor.save(in: fixture.context) == appointment.persistentModelID)
        #expect(appointment.startDate == Date(timeIntervalSinceReferenceDate: 300))
        #expect(appointment.notes == "Gate code changed")
        #expect(appointment.expectedDurationMinutes == 45)
        #expect(appointment.barn?.persistentModelID == originalBarnID)
        #expect(
            Set(appointment.appointmentHorses.compactMap(\.horse?.persistentModelID))
                == originalHorseIDs
        )
        #expect(Set(visit.visitHorses.map(\.persistentModelID)) == originalVisitHorseIDs)
    }

    @Test
    func appointmentWithoutVisitStillFailsWhenChoiceFetchesFail() throws {
        let fixture = try makeTwoHorseFixture()
        let appointment = ModelFixtures.makeAppointment(
            barn: fixture.barn,
            horses: fixture.horses,
            in: fixture.context
        )
        try DomainGraphValidator.save(fixture.context)
        let editor = AppointmentEditorModel(
            appointment: appointment,
            barnFetcher: { _ in throw ForcedFetchFailure.unavailable },
            horseFetcher: { _ in throw ForcedFetchFailure.unavailable }
        )

        editor.load(in: fixture.context)

        #expect(editor.loadState == .failed)
    }

    @Test
    func invalidVisitLockedGraphFailsClosedWithoutChoiceFetches() throws {
        let fixture = try makeTwoHorseFixture()
        let appointment = ModelFixtures.makeAppointment(
            barn: fixture.barn,
            horses: fixture.horses,
            in: fixture.context
        )
        let visit = ModelFixtures.makeVisit(
            appointment: appointment,
            in: fixture.context
        )
        try DomainGraphValidator.save(fixture.context)
        visit.barn = nil
        var barnFetchCount = 0
        var horseFetchCount = 0
        let editor = AppointmentEditorModel(
            appointment: appointment,
            barnFetcher: { _ in
                barnFetchCount += 1
                return []
            },
            horseFetcher: { _ in
                horseFetchCount += 1
                return []
            }
        )

        editor.load(in: fixture.context)

        #expect(editor.loadState == .failed)
        #expect(barnFetchCount == 0)
        #expect(horseFetchCount == 0)
    }

    @Test
    func invalidAppointmentMembershipFailsClosedWithoutChoiceFetches() throws {
        let fixture = try makeTwoHorseFixture()
        let appointment = ModelFixtures.makeAppointment(
            barn: fixture.barn,
            horses: fixture.horses,
            in: fixture.context
        )
        _ = ModelFixtures.makeVisit(
            appointment: appointment,
            in: fixture.context
        )
        try DomainGraphValidator.save(fixture.context)
        appointment.appointmentHorses[0].horse = nil
        var barnFetchCount = 0
        var horseFetchCount = 0
        let editor = AppointmentEditorModel(
            appointment: appointment,
            barnFetcher: { _ in
                barnFetchCount += 1
                return []
            },
            horseFetcher: { _ in
                horseFetchCount += 1
                return []
            }
        )

        editor.load(in: fixture.context)

        #expect(editor.loadState == .failed)
        #expect(barnFetchCount == 0)
        #expect(horseFetchCount == 0)
    }

    @Test
    func visitLocksBarnAndHorseMembershipWhileKeepingAppointmentFieldsEditable() throws {
        let fixture = try makeTwoHorseFixture()
        let otherBarn = Barn(name: "South Field")
        let otherClient = Client(name: "Casey")
        fixture.context.insert(otherBarn)
        fixture.context.insert(otherClient)
        let otherHorse = Horse(name: "River", client: otherClient, currentBarn: otherBarn)
        fixture.context.insert(otherHorse)
        otherClient.horses.append(otherHorse)
        otherBarn.horses.append(otherHorse)

        let appointment = ModelFixtures.makeAppointment(
            startDate: Date(timeIntervalSinceReferenceDate: 100),
            barn: fixture.barn,
            horses: fixture.horses,
            in: fixture.context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 200),
            appointment: appointment,
            in: fixture.context
        )
        try DomainGraphValidator.save(fixture.context)

        let originalBarnID = try #require(appointment.barn?.persistentModelID)
        let originalHorseIDs = Set(
            appointment.appointmentHorses.compactMap { $0.horse?.persistentModelID }
        )
        let originalVisitHorseIDs = Set(visit.visitHorses.map { $0.persistentModelID })
        let originalStartedAt = visit.startedAt
        let originalNameSnapshot = visit.serviceLocationNameSnapshot
        let originalAddressSnapshot = visit.serviceLocationAddressSnapshot

        let editor = AppointmentEditorModel(appointment: appointment)
        editor.load(in: fixture.context)

        #expect(editor.hasVisit)
        #expect(editor.lockedBarnName == "North Field")
        #expect(editor.lockedHorseNames == ["Milo", "Scout"])
        #expect(editor.draft.barnID == originalBarnID)
        #expect(editor.draft.selectedHorseIDs == originalHorseIDs)

        editor.selectBarn(otherBarn.persistentModelID, in: fixture.context)
        editor.toggleHorse(fixture.horses[0].persistentModelID)

        #expect(editor.draft.barnID == originalBarnID)
        #expect(editor.draft.selectedHorseIDs == originalHorseIDs)

        editor.draft.barnID = otherBarn.persistentModelID
        editor.draft.selectedHorseIDs = [otherHorse.persistentModelID]

        #expect(editor.save(in: fixture.context) == nil)
        #expect(appointment.barn?.persistentModelID == originalBarnID)
        #expect(
            Set(appointment.appointmentHorses.compactMap { $0.horse?.persistentModelID })
                == originalHorseIDs
        )
        #expect(Set(visit.visitHorses.map { $0.persistentModelID }) == originalVisitHorseIDs)
        #expect(visit.startedAt == originalStartedAt)
        #expect(visit.serviceLocationNameSnapshot == originalNameSnapshot)
        #expect(visit.serviceLocationAddressSnapshot == originalAddressSnapshot)

        editor.draft.barnID = originalBarnID
        editor.draft.selectedHorseIDs = originalHorseIDs
        editor.draft.startDate = Date(timeIntervalSinceReferenceDate: 300)
        editor.draft.notes = "  Gate code changed  "
        editor.draft.expectedDurationText = "45"

        #expect(editor.save(in: fixture.context) == appointment.persistentModelID)
        #expect(appointment.startDate == Date(timeIntervalSinceReferenceDate: 300))
        #expect(appointment.notes == "Gate code changed")
        #expect(appointment.expectedDurationMinutes == 45)
        #expect(appointment.barn?.persistentModelID == originalBarnID)
        #expect(
            Set(appointment.appointmentHorses.compactMap { $0.horse?.persistentModelID })
                == originalHorseIDs
        )
        #expect(Set(visit.visitHorses.map { $0.persistentModelID }) == originalVisitHorseIDs)
        #expect(visit.startedAt == originalStartedAt)
        #expect(visit.serviceLocationNameSnapshot == originalNameSnapshot)
        #expect(visit.serviceLocationAddressSnapshot == originalAddressSnapshot)
    }

    @Test
    func completedVisitRetainsLockedMembershipAfterHorseRelocationAndEditableSave() throws {
        let fixture = try makeTwoHorseFixture()
        let relocatedBarn = Barn(name: "South Field")
        fixture.context.insert(relocatedBarn)
        let appointment = ModelFixtures.makeAppointment(
            startDate: Date(timeIntervalSinceReferenceDate: 100),
            barn: fixture.barn,
            horses: fixture.horses,
            in: fixture.context
        )
        let visit = ModelFixtures.makeVisit(
            startedAt: Date(timeIntervalSinceReferenceDate: 200),
            completedAt: Date(timeIntervalSinceReferenceDate: 300),
            appointment: appointment,
            in: fixture.context
        )
        let service = ModelFixtures.makeService(in: fixture.context)
        for visitHorse in visit.visitHorses {
            visitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
            _ = ModelFixtures.makeWorkItem(
                service: service,
                visitHorse: visitHorse,
                in: fixture.context
            )
        }
        try DomainGraphValidator.save(fixture.context)

        let relocatedHorse = fixture.horses[0]
        relocatedHorse.currentBarn = relocatedBarn
        relocatedBarn.horses.append(relocatedHorse)
        try DomainGraphValidator.save(fixture.context)

        let originalHorseIDs = Set(
            appointment.appointmentHorses.compactMap { $0.horse?.persistentModelID }
        )
        let originalVisitHorseIDs = Set(visit.visitHorses.map { $0.persistentModelID })
        let originalStartedAt = visit.startedAt
        let originalCompletedAt = visit.completedAt
        let originalNameSnapshot = visit.serviceLocationNameSnapshot
        let originalAddressSnapshot = visit.serviceLocationAddressSnapshot

        let editor = AppointmentEditorModel(appointment: appointment)
        editor.load(in: fixture.context)

        #expect(editor.hasVisit)
        #expect(editor.lockedHorseNames == ["Milo", "Scout"])
        #expect(editor.draft.selectedHorseIDs == originalHorseIDs)
        #expect(editor.eligibleHorses.isEmpty)

        editor.draft.startDate = Date(timeIntervalSinceReferenceDate: 400)
        editor.draft.notes = "  Updated schedule  "
        editor.draft.expectedDurationText = "50"

        #expect(editor.save(in: fixture.context) == appointment.persistentModelID)
        #expect(appointment.startDate == Date(timeIntervalSinceReferenceDate: 400))
        #expect(appointment.notes == "Updated schedule")
        #expect(appointment.expectedDurationMinutes == 50)
        #expect(
            Set(appointment.appointmentHorses.compactMap { $0.horse?.persistentModelID })
                == originalHorseIDs
        )
        #expect(Set(visit.visitHorses.map { $0.persistentModelID }) == originalVisitHorseIDs)
        #expect(visit.startedAt == originalStartedAt)
        #expect(visit.completedAt == originalCompletedAt)
        #expect(visit.serviceLocationNameSnapshot == originalNameSnapshot)
        #expect(visit.serviceLocationAddressSnapshot == originalAddressSnapshot)
    }

    private func makeTwoHorseFixture() throws -> (
        container: ModelContainer,
        context: ModelContext,
        barn: Barn,
        horses: [Horse]
    ) {
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let barn = Barn(name: "North Field")
        let firstClient = Client(name: "Alex")
        let secondClient = Client(name: "Jordan")
        context.insert(barn)
        context.insert(firstClient)
        context.insert(secondClient)
        let firstHorse = Horse(name: "Milo", client: firstClient, currentBarn: barn)
        let secondHorse = Horse(name: "Scout", client: secondClient, currentBarn: barn)
        context.insert(firstHorse)
        context.insert(secondHorse)
        firstClient.horses.append(firstHorse)
        secondClient.horses.append(secondHorse)
        barn.horses.append(contentsOf: [firstHorse, secondHorse])
        try context.save()
        return (container, context, barn, [firstHorse, secondHorse])
    }
}
