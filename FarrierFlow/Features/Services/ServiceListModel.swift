import Foundation
import Observation
import OSLog
import SwiftData

nonisolated enum ServiceListLoadState: Equatable {
    case loading
    case loaded
    case failed
}

@MainActor
@Observable
final class ServiceListModel {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "ServiceList"
    )

    @ObservationIgnored private let serviceFetcher: (ModelContext) throws -> [Service]

    private(set) var services: [ServiceDetailSnapshot] = []
    private(set) var loadState: ServiceListLoadState = .loading

    var activeServices: [ServiceDetailSnapshot] {
        services.filter { !$0.isArchived }
    }

    var archivedServices: [ServiceDetailSnapshot] {
        services.filter(\.isArchived)
    }

    init(
        serviceFetcher: @escaping (ModelContext) throws -> [Service] = {
            try $0.fetch(FetchDescriptor<Service>())
        }
    ) {
        self.serviceFetcher = serviceFetcher
    }

    func load(in context: ModelContext, locale: Locale = .current) {
        loadState = .loading
        do {
            services = ServiceRules.sorted(try serviceFetcher(context), locale: locale).map(ServiceDetailSnapshot.init)
            loadState = .loaded
        } catch {
            Self.logger.error("Failed to load services: \(error, privacy: .public)")
            loadState = .failed
        }
    }
}
