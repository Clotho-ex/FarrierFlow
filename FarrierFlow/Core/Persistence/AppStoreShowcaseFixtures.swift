#if DEBUG
import Foundation
import ImageIO
import SwiftData

extension UITestFixtures {
    private enum AppStoreShowcaseSeedError: Error {
        case unexpectedStoreContents
        case invalidPhotographSource
        case photographCleanupFailed
    }

    private struct ShowcasePhotographSource {
        let id: UUID
        let data: Data
        let pixelWidth: Int
        let pixelHeight: Int
    }

    private struct ShowcaseWork {
        let serviceID: PersistentIdentifier
        let serviceName: String
        let amountMinorUnits: Int64
        let notes: String
    }

    private struct ShowcaseTodayTimes {
        let morning: Date
        let midday: Date
        let afternoon: Date
    }

    private static let showcaseBusinessName = "Northline Farrier Service"
    private static let showcaseTodayAppointmentNotes = "Work from the main stable aisle; Atlas first."

    static func seedAppStoreShowcase(
        in container: ModelContainer,
        photographRootURL: URL,
        photographSourceURL: URL?,
        now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        stage: ScreenshotFixtureStage = .active
    ) throws {
        let photographSources = try photographSourceURL.map(loadShowcasePhotographSources)
        let context = container.mainContext
        let profiles = try context.fetch(FetchDescriptor<BusinessProfile>())
        if profiles.contains(where: { $0.name == showcaseBusinessName }) {
            guard profiles.count == 1 else {
                throw AppStoreShowcaseSeedError.unexpectedStoreContents
            }
            let visits = try context.fetch(FetchDescriptor<Visit>())
            let activeVisitCount = visits.filter { $0.completedAt == nil }.count
            let expectedActiveVisitCount = stage == .active ? 1 : 0
            guard activeVisitCount == expectedActiveVisitCount else {
                throw AppStoreShowcaseSeedError.unexpectedStoreContents
            }
            try refreshShowcaseToday(
                in: container,
                now: now,
                calendar: calendar,
                stage: stage
            )
            if let photographSources {
                guard let currentVisit = visits.first(where: {
                    $0.appointment?.notes == showcaseTodayAppointmentNotes
                }) else {
                    throw AppStoreShowcaseSeedError.unexpectedStoreContents
                }
                try seedShowcasePhotographs(
                    on: currentVisit.persistentModelID,
                    sources: photographSources,
                    rootURL: photographRootURL,
                    in: container
                )
            }
            try DomainGraphValidator.validateAll(in: ModelContext(container))
            return
        }

        guard profiles.isEmpty,
              try context.fetchCount(FetchDescriptor<Client>()) == 0,
              try context.fetchCount(FetchDescriptor<Barn>()) == 0,
              try context.fetchCount(FetchDescriptor<Horse>()) == 0,
              try context.fetchCount(FetchDescriptor<Appointment>()) == 0,
              try context.fetchCount(FetchDescriptor<Visit>()) == 0,
              try context.fetchCount(FetchDescriptor<Invoice>()) == 0
        else {
            throw AppStoreShowcaseSeedError.unexpectedStoreContents
        }

        let profile = BusinessProfile(
            name: showcaseBusinessName,
            phone: "(555) 014-2763",
            email: "hello@northlinefarrier.example",
            address: "42 Fieldline Road, Lexington, KY 40511",
            defaultInvoiceNote: "Thank you for trusting Northline Farrier Service.",
            defaultAppointmentDurationMinutes: 90,
            defaultInvoiceDueDays: 14,
            nextInvoiceNumber: 148
        )
        let jordan = Client(
            name: "Jordan Ellis",
            phone: "(555) 014-1182",
            email: "jordan.ellis@example.com",
            notes: "Text before arrival at the main stable aisle."
        )
        let morgan = Client(
            name: "Morgan Reed",
            phone: "(555) 014-2246",
            email: "morgan.reed@example.com"
        )
        let casey = Client(
            name: "Casey Bennett",
            phone: "(555) 014-3379",
            email: "casey.bennett@example.com"
        )
        let willow = Barn(
            name: "Willow Creek Stables",
            address: "100 Willow Creek Road, Lexington, KY 40511",
            contactNotes: "Park beside the indoor arena."
        )
        let oak = Barn(
            name: "Oak Ridge Farm",
            address: "240 Oak Ridge Lane, Georgetown, KY 40324"
        )
        let cedar = Barn(
            name: "Cedar Run Equestrian",
            address: "375 Cedar Run Drive, Versailles, KY 40383"
        )
        let trim = Service(name: "Trim", defaultAmountMinorUnits: 5_500)
        let frontShoes = Service(name: "Front Shoes", defaultAmountMinorUnits: 13_500)
        let fullSet = Service(name: "Full Set", defaultAmountMinorUnits: 22_000)

        context.insert(profile)
        [jordan, morgan, casey].forEach(context.insert)
        [willow, oak, cedar].forEach(context.insert)
        [trim, frontShoes, fullSet].forEach(context.insert)

        let atlas = Horse(
            name: "Atlas",
            safetyNotes: "Steady in the aisle; watch the right-front flare.",
            appointmentIntervalWeeks: 4,
            client: jordan,
            currentBarn: willow,
            defaultService: fullSet
        )
        let beacon = Horse(
            name: "Beacon",
            appointmentIntervalWeeks: 6,
            client: jordan,
            currentBarn: willow,
            defaultService: frontShoes
        )
        let clover = Horse(
            name: "Clover",
            appointmentIntervalWeeks: 8,
            client: jordan,
            currentBarn: willow,
            defaultService: trim
        )
        let scout = Horse(
            name: "Scout",
            appointmentIntervalWeeks: 6,
            client: morgan,
            currentBarn: oak,
            defaultService: trim
        )
        let milo = Horse(
            name: "Milo",
            appointmentIntervalWeeks: 6,
            client: morgan,
            currentBarn: oak,
            defaultService: frontShoes
        )
        let luna = Horse(
            name: "Luna",
            appointmentIntervalWeeks: 5,
            client: casey,
            currentBarn: cedar,
            defaultService: trim
        )
        let jasper = Horse(
            name: "Jasper",
            appointmentIntervalWeeks: 6,
            client: casey,
            currentBarn: cedar,
            defaultService: fullSet
        )
        let horses = [atlas, beacon, clover, scout, milo, luna, jasper]
        horses.forEach(context.insert)
        jordan.horses.append(contentsOf: [atlas, beacon, clover])
        morgan.horses.append(contentsOf: [scout, milo])
        casey.horses.append(contentsOf: [luna, jasper])
        willow.horses.append(contentsOf: [atlas, beacon, clover])
        oak.horses.append(contentsOf: [scout, milo])
        cedar.horses.append(contentsOf: [luna, jasper])
        fullSet.horsesUsingAsDefault.append(contentsOf: [atlas, jasper])
        frontShoes.horsesUsingAsDefault.append(contentsOf: [beacon, milo])
        trim.horsesUsingAsDefault.append(contentsOf: [clover, scout, luna])

        let today = showcaseTodayTimes(now: now, calendar: calendar)
        let willowToday = makeShowcaseAppointment(
            startDate: today.morning,
            notes: showcaseTodayAppointmentNotes,
            expectedDurationMinutes: 120,
            barn: willow,
            horses: [atlas, beacon, clover],
            in: context
        )
        _ = makeShowcaseAppointment(
            startDate: today.midday,
            notes: "Scout and Milo in the south paddock.",
            expectedDurationMinutes: 90,
            barn: oak,
            horses: [scout, milo],
            in: context
        )
        _ = makeShowcaseAppointment(
            startDate: today.afternoon,
            notes: "Meet at the covered grooming bays.",
            expectedDurationMinutes: 90,
            barn: cedar,
            horses: [luna, jasper],
            in: context
        )

        let sourceStart = date(weeksBefore: 4, from: today.morning, calendar: calendar)
        let sourceAppointment = makeShowcaseAppointment(
            startDate: sourceStart,
            notes: "Routine interval visit.",
            expectedDurationMinutes: 120,
            barn: willow,
            horses: [atlas, beacon, clover],
            in: context
        )
        let olderStarts = [8, 12, 16, 20].map {
            date(weeksBefore: $0, from: today.morning, calendar: calendar)
        }
        let olderAppointments = olderStarts.map { startDate in
            makeShowcaseAppointment(
                startDate: startDate,
                notes: "Atlas maintenance visit.",
                expectedDurationMinutes: 60,
                barn: willow,
                horses: [atlas],
                in: context
            )
        }
        try DomainGraphValidator.save(context)

        let fullSetWork = ShowcaseWork(
            serviceID: fullSet.persistentModelID,
            serviceName: fullSet.name,
            amountMinorUnits: fullSet.defaultAmountMinorUnits,
            notes: "Reset full set; balanced breakover and finished clinches."
        )
        let frontShoesWork = ShowcaseWork(
            serviceID: frontShoes.persistentModelID,
            serviceName: frontShoes.name,
            amountMinorUnits: frontShoes.defaultAmountMinorUnits,
            notes: "Reset fronts and eased the lateral toe."
        )
        let trimWork = ShowcaseWork(
            serviceID: trim.persistentModelID,
            serviceName: trim.name,
            amountMinorUnits: trim.defaultAmountMinorUnits,
            notes: "Balanced trim with heels brought back evenly."
        )

        let sourceVisitID = try completeShowcaseVisit(
            appointmentID: sourceAppointment.persistentModelID,
            startedAt: sourceStart,
            workByHorseName: [atlas.name: fullSetWork, beacon.name: frontShoesWork],
            in: container
        )
        let olderWork = [trimWork, frontShoesWork, fullSetWork, trimWork]
        for (appointment, work) in zip(olderAppointments, olderWork) {
            _ = try completeShowcaseVisit(
                appointmentID: appointment.persistentModelID,
                startedAt: appointment.startDate,
                workByHorseName: [atlas.name: work],
                in: container
            )
        }

        let invoiceVisitID: PersistentIdentifier
        let currentVisitID: PersistentIdentifier
        switch stage {
        case .active:
            currentVisitID = try saveActiveShowcaseVisit(
                appointmentID: willowToday.persistentModelID,
                startedAt: today.morning,
                workByHorseName: [atlas.name: fullSetWork, beacon.name: frontShoesWork],
                in: container
            )
            invoiceVisitID = sourceVisitID
        case .completed:
            invoiceVisitID = try completeShowcaseVisit(
                appointmentID: willowToday.persistentModelID,
                startedAt: today.morning,
                workByHorseName: [atlas.name: fullSetWork, beacon.name: frontShoesWork],
                in: container
            )
            currentVisitID = invoiceVisitID
        }

        if let photographSources {
            try seedShowcasePhotographs(
                on: currentVisitID,
                sources: photographSources,
                rootURL: photographRootURL,
                in: container
            )
        }

        let invoiceContext = ModelContext(container)
        let invoiceDate = stage == .completed
            ? now
            : sourceStart.addingTimeInterval(2 * 60 * 60)
        _ = try InvoiceGenerationUseCase.generate(
            InvoiceCreationDraft(
                clientID: jordan.persistentModelID,
                selectedVisitIDs: [invoiceVisitID],
                invoiceDate: invoiceDate,
                dueDate: calendar.date(byAdding: .day, value: 14, to: invoiceDate),
                note: "Thank you. Payment is due within 14 days."
            ),
            in: invoiceContext
        )

        try refreshShowcaseToday(
            in: container,
            now: now,
            calendar: calendar,
            stage: stage
        )
        try DomainGraphValidator.validateAll(in: ModelContext(container))
    }

    private static func refreshShowcaseToday(
        in container: ModelContainer,
        now: Date,
        calendar: Calendar,
        stage: ScreenshotFixtureStage
    ) throws {
        let context = ModelContext(container)
        let times = showcaseTodayTimes(now: now, calendar: calendar)
        let appointments = try context.fetch(FetchDescriptor<Appointment>())
        guard let willow = appointments.first(where: {
            let isTodayAppointment = $0.notes == showcaseTodayAppointmentNotes
            let hasExpectedHorses = Set($0.appointmentHorses.compactMap(\.horse?.name))
                == Set(["Atlas", "Beacon", "Clover"])
            let hasExpectedVisitState = switch stage {
            case .active:
                $0.visit?.completedAt == nil
            case .completed:
                $0.visit?.completedAt != nil
            }
            return isTodayAppointment && hasExpectedHorses && hasExpectedVisitState
        }),
        let oak = appointments.first(where: {
            $0.visit == nil
                && Set($0.appointmentHorses.compactMap(\.horse?.name))
                    == Set(["Scout", "Milo"])
        }),
        let cedar = appointments.first(where: {
            $0.visit == nil
                && Set($0.appointmentHorses.compactMap(\.horse?.name))
                    == Set(["Luna", "Jasper"])
        }) else {
            throw AppStoreShowcaseSeedError.unexpectedStoreContents
        }

        willow.startDate = times.morning
        willow.visit?.startedAt = times.morning
        if stage == .completed {
            willow.visit?.completedAt = times.morning.addingTimeInterval(90 * 60)
        }
        oak.startDate = times.midday
        cedar.startDate = times.afternoon
        try DomainGraphValidator.save(context)
    }

    private static func loadShowcasePhotographSources(
        from directory: URL
    ) throws -> [ShowcasePhotographSource] {
        let directoryValues = try directory.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard directoryValues.isDirectory == true,
              directoryValues.isSymbolicLink != true else {
            throw AppStoreShowcaseSeedError.invalidPhotographSource
        }

        return try (1...6).map { index in
            let url = directory.appending(path: "Hoof-Image-\(index).jpeg")
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true,
                  values.isSymbolicLink != true else {
                throw AppStoreShowcaseSeedError.invalidPhotographSource
            }
            let data = try Data(contentsOf: url)
            guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                  CGImageSourceGetCount(imageSource) == 1,
                  let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
                    as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int,
                  width > 0, height > 0,
                  max(width, height) <= PhotographConstants.maximumLongestEdge else {
                throw AppStoreShowcaseSeedError.invalidPhotographSource
            }
            return ShowcasePhotographSource(
                id: UUID(uuid: (
                    0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0, UInt8(index)
                )),
                data: data,
                pixelWidth: width,
                pixelHeight: height
            )
        }
    }

    private static func seedShowcasePhotographs(
        on visitID: PersistentIdentifier,
        sources: [ShowcasePhotographSource],
        rootURL: URL,
        in container: ModelContainer
    ) throws {
        let context = ModelContext(container)
        guard let visit = try context.existingModel(Visit.self, for: visitID),
              let atlas = visit.visitHorses.first(where: { $0.horse?.name == "Atlas" }) else {
            throw AppStoreShowcaseSeedError.unexpectedStoreContents
        }
        let fileStore = PhotographFileStore(rootURL: rootURL)
        try fileStore.prepareDirectories()

        if !atlas.photographs.isEmpty {
            guard atlas.photographs.count == sources.count,
                  Set(atlas.photographs.map(\.id)) == Set(sources.map(\.id)) else {
                throw AppStoreShowcaseSeedError.unexpectedStoreContents
            }
            for source in sources {
                guard try Data(contentsOf: fileStore.canonicalURL(for: source.id))
                    == source.data else {
                    throw AppStoreShowcaseSeedError.unexpectedStoreContents
                }
            }
            return
        }

        var writtenURLs: [URL] = []
        do {
            for source in sources {
                let url = fileStore.canonicalURL(for: source.id)
                guard !FileManager.default.fileExists(atPath: url.path) else {
                    throw AppStoreShowcaseSeedError.unexpectedStoreContents
                }
                try source.data.write(to: url, options: .atomic)
                writtenURLs.append(url)
                try fileStore.applyCompleteProtection(to: url)
                let photograph = Photograph(
                    id: source.id,
                    createdAt: visit.startedAt,
                    pixelWidth: source.pixelWidth,
                    pixelHeight: source.pixelHeight,
                    byteCount: Int64(source.data.count),
                    visitHorse: atlas
                )
                context.insert(photograph)
                atlas.photographs.append(photograph)
            }
            try DomainGraphValidator.save(context)
        } catch {
            context.rollback()
            for url in writtenURLs {
                do {
                    try fileStore.removeManagedFile(at: url)
                } catch {
                    throw AppStoreShowcaseSeedError.photographCleanupFailed
                }
            }
            throw error
        }
    }

    private static func saveActiveShowcaseVisit(
        appointmentID: PersistentIdentifier,
        startedAt: Date,
        workByHorseName: [String: ShowcaseWork],
        in container: ModelContainer
    ) throws -> PersistentIdentifier {
        let visitID = try VisitStartUseCase.start(
            appointmentID: appointmentID,
            now: startedAt,
            in: container
        )
        let context = ModelContext(container)
        var draft = try VisitSaveUseCase.loadDraft(visitID: visitID, in: context)
        applyShowcaseWork(workByHorseName, to: &draft)
        _ = try VisitSaveUseCase.saveProgress(draft: draft, in: context)
        return visitID
    }

    private static func completeShowcaseVisit(
        appointmentID: PersistentIdentifier,
        startedAt: Date,
        workByHorseName: [String: ShowcaseWork],
        in container: ModelContainer
    ) throws -> PersistentIdentifier {
        let visitID = try VisitStartUseCase.start(
            appointmentID: appointmentID,
            now: startedAt,
            in: container
        )
        let context = ModelContext(container)
        var draft = try VisitSaveUseCase.loadDraft(visitID: visitID, in: context)
        applyShowcaseWork(workByHorseName, to: &draft)
        _ = try VisitSaveUseCase.complete(
            draft: draft,
            completedAt: startedAt.addingTimeInterval(90 * 60),
            in: context
        )
        return visitID
    }

    private static func applyShowcaseWork(
        _ workByHorseName: [String: ShowcaseWork],
        to draft: inout VisitDraft
    ) {
        for index in draft.horses.indices {
            let horseName = draft.horses[index].horseName
            guard let work = workByHorseName[horseName] else {
                draft.horses[index].outcome = .notServiced
                draft.horses[index].workNotes = ""
                draft.horses[index].workItems = []
                continue
            }
            draft.horses[index].outcome = .serviced
            draft.horses[index].workNotes = work.notes
            draft.horses[index].workItems = [
                WorkItemDraft(
                    serviceID: work.serviceID,
                    serviceNameSnapshot: work.serviceName,
                    amountMinorUnits: work.amountMinorUnits
                ),
            ]
        }
    }

    private static func makeShowcaseAppointment(
        startDate: Date,
        notes: String,
        expectedDurationMinutes: Int,
        barn: Barn,
        horses: [Horse],
        in context: ModelContext
    ) -> Appointment {
        let appointment = Appointment(
            startDate: startDate,
            notes: notes,
            expectedDurationMinutes: expectedDurationMinutes,
            barn: barn
        )
        context.insert(appointment)
        barn.appointments.append(appointment)
        for horse in horses {
            let membership = AppointmentHorse(appointment: appointment, horse: horse)
            context.insert(membership)
            appointment.appointmentHorses.append(membership)
            horse.appointmentHorses.append(membership)
        }
        return appointment
    }

    private static func showcaseTodayTimes(
        now: Date,
        calendar: Calendar
    ) -> ShowcaseTodayTimes {
        let day = calendar.startOfDay(for: now)
        let conventionalMorning = calendar.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: day
        ) ?? day
        let earliestToday = calendar.date(byAdding: .minute, value: 1, to: day) ?? day
        let recentlyStarted = calendar.date(byAdding: .minute, value: -5, to: now) ?? now
        let morning = min(conventionalMorning, max(earliestToday, recentlyStarted))
        let midday = calendar.date(
            bySettingHour: 12,
            minute: 0,
            second: 0,
            of: day
        ) ?? day
        let afternoon = calendar.date(
            bySettingHour: 15,
            minute: 30,
            second: 0,
            of: day
        ) ?? day
        return ShowcaseTodayTimes(morning: morning, midday: midday, afternoon: afternoon)
    }

    private static func date(
        weeksBefore weeks: Int,
        from date: Date,
        calendar: Calendar
    ) -> Date {
        calendar.date(byAdding: .weekOfYear, value: -weeks, to: date) ?? date
    }
}
#endif
