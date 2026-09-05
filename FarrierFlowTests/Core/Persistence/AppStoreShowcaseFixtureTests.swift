import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("App Store showcase fixture", .serialized)
@MainActor
struct AppStoreShowcaseFixtureTests {
    @Test
    func seedIsValidIdempotentAndReopensWithoutDuplicates() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-App-Store-Showcase-"
        )
        let storeURL = directory.appending(path: "showcase.store")
        let photographRootURL = directory.appending(
            path: PhotographConstants.rootDirectoryName,
            directoryHint: .isDirectory
        )

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            try UITestFixtures.seed(
                .appStoreShowcase,
                in: container,
                photographRootURL: photographRootURL
            )
            try UITestFixtures.seed(
                .appStoreShowcase,
                in: container,
                photographRootURL: photographRootURL
            )

            try verifyShowcase(in: container)
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            try UITestFixtures.seed(
                .appStoreShowcase,
                in: container,
                photographRootURL: photographRootURL
            )

            try verifyShowcase(in: container)
            try verifyNextAppointmentAfterCompletingActiveVisit(in: container)
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            try UITestFixtures.seed(
                .appStoreShowcase,
                in: container,
                photographRootURL: photographRootURL
            )
            let context = ModelContext(container)
            #expect(
                try context.fetch(FetchDescriptor<Visit>())
                    .allSatisfy { $0.completedAt != nil }
            )
            try DomainGraphValidator.validateAll(in: context)
        }
    }

    private func verifyShowcase(in container: ModelContainer) throws {
        let context = ModelContext(container)
        try DomainGraphValidator.validateAll(in: context)

        #expect(try context.fetchCount(FetchDescriptor<BusinessProfile>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Client>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<Barn>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<Horse>()) == 7)
        #expect(try context.fetchCount(FetchDescriptor<Service>()) == 3)
        #expect(try context.fetchCount(FetchDescriptor<Appointment>()) == 8)
        #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 6)
        #expect(try context.fetchCount(FetchDescriptor<Invoice>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Photograph>()) == 0)

        let profile = try #require(context.fetch(FetchDescriptor<BusinessProfile>()).first)
        #expect(profile.name == "Northline Farrier Service")

        let todayModel = TodayModel()
        todayModel.load(
            in: context,
            now: .now,
            calendar: .autoupdatingCurrent
        )
        #expect(todayModel.loadState == .loaded)
        guard case .resumeVisit(let activeVisit) = todayModel.primaryAction else {
            Issue.record("Today did not promote the active showcase visit")
            return
        }
        #expect(activeVisit.serviceLocationName == "Willow Creek Stables")
        #expect(activeVisit.horseNames == ["Atlas", "Beacon", "Clover"])
        #expect(activeVisit.resolvedHorseCount == 3)
        #expect(activeVisit.totalHorseCount == 3)
        #expect(
            todayModel.remainingAppointments.map(\.serviceLocationName)
                == ["Oak Ridge Farm", "Cedar Run Equestrian"]
        )

        let activeDraft = try VisitSaveUseCase.loadDraft(
            visitID: activeVisit.id,
            in: context
        )
        #expect(VisitRules.completionViolation(in: activeDraft) == nil)
        #expect(activeDraft.horses.first { $0.horseName == "Atlas" }?.outcome == .serviced)
        #expect(
            activeDraft.horses.first { $0.horseName == "Atlas" }?
                .workItems.first?.serviceNameSnapshot == "Full Set"
        )
        #expect(activeDraft.horses.first { $0.horseName == "Beacon" }?.outcome == .serviced)
        #expect(
            activeDraft.horses.first { $0.horseName == "Beacon" }?
                .workItems.first?.serviceNameSnapshot == "Front Shoes"
        )
        #expect(activeDraft.horses.first { $0.horseName == "Clover" }?.outcome == .notServiced)

        let atlas = try #require(
            context.fetch(FetchDescriptor<Horse>()).first { $0.name == "Atlas" }
        )
        let horseModel = HorseDetailModel()
        horseModel.load(
            id: atlas.persistentModelID,
            in: context,
            locale: Locale(identifier: "en_US")
        )
        #expect(horseModel.historyLoadState == .loaded)
        #expect(horseModel.history.count == 5)

        let invoice = try #require(context.fetch(FetchDescriptor<Invoice>()).first)
        let invoiceModel = InvoiceDetailModel(invoiceID: invoice.persistentModelID)
        invoiceModel.load(in: context, locale: Locale(identifier: "en_US"))
        #expect(invoiceModel.loadState == .loaded)
        #expect(invoiceModel.detail?.number == "0148")
        #expect(invoiceModel.detail?.status == .unpaid)
        #expect(invoiceModel.detail?.total == .available(35_500))
        #expect(
            invoiceModel.detail?.visits.flatMap(\.lineItems).map(\.horseName)
                == ["Atlas", "Beacon"]
        )
    }

    private func verifyNextAppointmentAfterCompletingActiveVisit(
        in container: ModelContainer
    ) throws {
        let context = ModelContext(container)
        let followUpVisit = try #require(
            context.fetch(FetchDescriptor<Visit>()).first { $0.completedAt == nil }
        )
        let draft = try VisitSaveUseCase.loadDraft(
            visitID: followUpVisit.persistentModelID,
            in: context
        )
        _ = try VisitSaveUseCase.complete(
            draft: draft,
            completedAt: max(Date.now, followUpVisit.startedAt),
            in: context
        )

        let assistant = NextAppointmentAssistantModel(
            visitID: followUpVisit.persistentModelID
        )
        let calendar = Calendar.autoupdatingCurrent
        let now = Date.now
        let endOfToday = calendar.date(
            byAdding: .second,
            value: -1,
            to: CalendarRules.dayInterval(containing: now, calendar: calendar).end
        ) ?? now
        assistant.load(
            in: context,
            now: endOfToday,
            calendar: calendar,
            locale: Locale(identifier: "en_US")
        )
        #expect(assistant.loadState == .loaded)
        let options = try #require(assistant.projection?.options)
        #expect(options.map(\.horseName) == ["Atlas", "Beacon", "Clover"])
        #expect(options.first { $0.horseName == "Atlas" }?.intervalWeeks == 4)
        #expect(options.first { $0.horseName == "Atlas" }?.isSelected == true)
        #expect(options.first { $0.horseName == "Beacon" }?.intervalWeeks == 6)
        #expect(options.first { $0.horseName == "Beacon" }?.isSelected == true)
        #expect(options.first { $0.horseName == "Clover" }?.outcome == .notServiced)
        #expect(options.first { $0.horseName == "Clover" }?.isSelected == false)
    }
}
