import Foundation
import SwiftData
import Testing
import UIKit
@testable import FarrierFlow

@Suite("App Store showcase fixture", .serialized)
@MainActor
struct AppStoreShowcaseFixtureTests {
    @Test
    func seedIsValidIdempotentAndReopensWithoutDuplicates() throws {
        let (referenceDate, calendar) = try fixtureClock()
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-App-Store-Showcase-"
        )
        let storeURL = directory.appending(path: "showcase.store")
        let photographRootURL = directory.appending(
            path: PhotographConstants.rootDirectoryName,
            directoryHint: .isDirectory
        )
        let sourceURL = try makePhotoSources(in: directory)

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            try UITestFixtures.seed(
                .appStoreShowcase,
                in: container,
                photographRootURL: photographRootURL,
                showcasePhotoSourceURL: sourceURL,
                now: referenceDate,
                calendar: calendar,
                screenshotStage: .active
            )
            try UITestFixtures.seed(
                .appStoreShowcase,
                in: container,
                photographRootURL: photographRootURL,
                showcasePhotoSourceURL: sourceURL,
                now: referenceDate,
                calendar: calendar,
                screenshotStage: .active
            )

            try verifyShowcase(
                in: container,
                now: referenceDate,
                calendar: calendar,
                photographRootURL: photographRootURL,
                sourceURL: sourceURL
            )
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            try UITestFixtures.seed(
                .appStoreShowcase,
                in: container,
                photographRootURL: photographRootURL,
                showcasePhotoSourceURL: sourceURL,
                now: referenceDate,
                calendar: calendar,
                screenshotStage: .active
            )

            try verifyShowcase(
                in: container,
                now: referenceDate,
                calendar: calendar,
                photographRootURL: photographRootURL,
                sourceURL: sourceURL
            )
            try verifyNextAppointmentAfterCompletingActiveVisit(
                in: container,
                now: referenceDate,
                calendar: calendar
            )
        }

    }

    @Test
    func completedStageUsesCurrentVisitForInvoiceAndFollowUp() throws {
        let (referenceDate, calendar) = try fixtureClock()
        let directory = try TemporaryStoreFixtures.makeDirectory(
            prefix: "FarrierFlow-App-Store-Showcase-Completed-"
        )
        let storeURL = directory.appending(path: "showcase.store")
        let photographRootURL = directory.appending(
            path: PhotographConstants.rootDirectoryName,
            directoryHint: .isDirectory
        )
        let sourceURL = try makePhotoSources(in: directory)

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            for _ in 0..<2 {
                try UITestFixtures.seed(
                    .appStoreShowcase,
                    in: container,
                    photographRootURL: photographRootURL,
                    showcasePhotoSourceURL: sourceURL,
                    now: referenceDate,
                    calendar: calendar,
                    screenshotStage: .completed
                )
            }

            let context = ModelContext(container)
            try DomainGraphValidator.validateAll(in: context)
            #expect(try context.fetchCount(FetchDescriptor<Appointment>()) == 8)
            #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 6)
            #expect(try context.fetchCount(FetchDescriptor<Invoice>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<Photograph>()) == 6)
            #expect(
                try context.fetch(FetchDescriptor<Visit>())
                    .allSatisfy { $0.completedAt != nil }
            )

            let invoice = try #require(context.fetch(FetchDescriptor<Invoice>()).first)
            let invoiceModel = InvoiceDetailModel(invoiceID: invoice.persistentModelID)
            invoiceModel.load(in: context, locale: Locale(identifier: "en_US"))
            #expect(invoiceModel.detail?.number == "0148")
            #expect(invoiceModel.detail?.invoiceDate == referenceDate)
            #expect(invoiceModel.detail?.total == .available(35_500))
            let expectedVisitStart = try #require(
                calendar.date(
                    bySettingHour: 8,
                    minute: 0,
                    second: 0,
                    of: referenceDate
                )
            )
            #expect(invoiceModel.detail?.visits.first?.visitDate == expectedVisitStart)

            let atlas = try #require(
                context.fetch(FetchDescriptor<Horse>()).first { $0.name == "Atlas" }
            )
            let horseModel = HorseDetailModel()
            horseModel.load(
                id: atlas.persistentModelID,
                in: context,
                locale: Locale(identifier: "en_US")
            )
            let expectedHistoryDates = try [0, 4, 8, 12, 16, 20].map { weeksAgo in
                try #require(
                    calendar.date(
                        byAdding: .weekOfYear,
                        value: -weeksAgo,
                        to: expectedVisitStart
                    )
                )
            }
            #expect(horseModel.history.map(\.startedAt) == expectedHistoryDates)

            let willowVisit = try #require(
                context.fetch(FetchDescriptor<Visit>()).first {
                    $0.appointment?.barn?.name == "Willow Creek Stables"
                        && calendar.isDate($0.startedAt, inSameDayAs: referenceDate)
                }
            )
            let assistant = NextAppointmentAssistantModel(
                visitID: willowVisit.persistentModelID
            )
            assistant.load(
                in: context,
                now: referenceDate,
                calendar: calendar,
                locale: Locale(identifier: "en_US")
            )
            let projection = try #require(assistant.projection)
            #expect(projection.options.map(\.horseName) == ["Atlas", "Beacon", "Clover"])
            #expect(
                projection.options.first { $0.horseName == "Atlas" }?.suggestedStart
                    == calendar.date(byAdding: .weekOfYear, value: 4, to: willowVisit.startedAt)
            )
        }

        try autoreleasepool {
            let container = try ModelContainerFactory.persistentStoreTest(at: storeURL)
            try UITestFixtures.seed(
                .appStoreShowcase,
                in: container,
                photographRootURL: photographRootURL,
                showcasePhotoSourceURL: sourceURL,
                now: referenceDate,
                calendar: calendar,
                screenshotStage: .completed
            )
            let context = ModelContext(container)
            #expect(try context.fetchCount(FetchDescriptor<Visit>()) == 6)
            #expect(try context.fetchCount(FetchDescriptor<Invoice>()) == 1)
            #expect(try context.fetchCount(FetchDescriptor<Photograph>()) == 6)
            try DomainGraphValidator.validateAll(in: context)
        }
    }

    private func verifyShowcase(
        in container: ModelContainer,
        now: Date,
        calendar: Calendar,
        photographRootURL: URL,
        sourceURL: URL
    ) throws {
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
        #expect(try context.fetchCount(FetchDescriptor<Photograph>()) == 6)

        let profile = try #require(context.fetch(FetchDescriptor<BusinessProfile>()).first)
        #expect(profile.name == "Northline Farrier Service")

        let todayModel = TodayModel()
        todayModel.load(
            in: context,
            now: now,
            calendar: calendar
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
        let activeVisitRecord = try #require(
            try context.existingModel(Visit.self, for: activeVisit.id)
        )
        let atlasVisitHorse = try #require(
            activeVisitRecord.visitHorses.first { $0.horse?.name == "Atlas" }
        )
        #expect(atlasVisitHorse.photographs.count == 6)
        #expect(
            activeVisitRecord.visitHorses
                .filter { $0.horse?.name != "Atlas" }
                .allSatisfy { $0.photographs.isEmpty }
        )
        let fileStore = PhotographFileStore(rootURL: photographRootURL)
        for index in 1...6 {
            let photograph = try #require(
                atlasVisitHorse.photographs.first {
                    $0.id == showcasePhotographID(index: index)
                }
            )
            #expect(photograph.createdAt == activeVisitRecord.startedAt)
            let canonicalData = try Data(contentsOf: fileStore.canonicalURL(for: photograph.id))
            let sourceData = try Data(contentsOf: sourceURL.appending(path: "Hoof-Image-\(index).jpeg"))
            #expect(canonicalData == sourceData)
        }
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
        in container: ModelContainer,
        now: Date,
        calendar: Calendar
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
            completedAt: max(now, followUpVisit.startedAt),
            in: context
        )

        let assistant = NextAppointmentAssistantModel(
            visitID: followUpVisit.persistentModelID
        )
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

    private func fixtureClock() throws -> (Date, Calendar) {
        let referenceDate = try #require(
            ISO8601DateFormatter().date(from: "2026-09-06T13:41:00Z")
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        return (referenceDate, calendar)
    }

    private func makePhotoSources(in directory: URL) throws -> URL {
        let sourceURL = directory.appending(path: "ShowcaseHoofPhotos", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: sourceURL, withIntermediateDirectories: true)
        for index in 1...6 {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image {
                $0.cgContext.setFillColor(UIColor(white: CGFloat(index) / 7, alpha: 1).cgColor)
                $0.cgContext.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            }
            let data = try #require(image.jpegData(compressionQuality: 0.8))
            try data.write(to: sourceURL.appending(path: "Hoof-Image-\(index).jpeg"))
        }
        return sourceURL
    }

    private func showcasePhotographID(index: Int) -> UUID? {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index))
    }
}
