import Foundation
import OSLog

@MainActor
enum AnalyticsClientComposition {
    private static let logger = Logger(
        subsystem: "com.farrierflow.yusufcan.FarrierFlow",
        category: "AnalyticsConfiguration"
    )

    static func make(
        infoDictionary: [String: Any],
        providerFactory: ((PostHogAnalyticsConfiguration) -> any AnalyticsClient)? = nil
    ) -> any AnalyticsClient {
        do {
            let configuration = try PostHogAnalyticsConfiguration(
                infoDictionary: infoDictionary
            )
            if let providerFactory {
                return providerFactory(configuration)
            }
            return PostHogAnalyticsClient(configuration: configuration)
        } catch let error as PostHogAnalyticsConfigurationError {
            #if DEBUG
            logger.error("Analytics disabled: \(error.diagnosticDescription, privacy: .public)")
            #endif
            return NoOpAnalyticsClient()
        } catch {
            #if DEBUG
            logger.error("Analytics disabled because configuration could not be read.")
            #endif
            return NoOpAnalyticsClient()
        }
    }

    static func make(
        bundle: Bundle = .main,
        providerFactory: ((PostHogAnalyticsConfiguration) -> any AnalyticsClient)? = nil
    ) -> any AnalyticsClient {
        make(
            infoDictionary: bundle.infoDictionary ?? [:],
            providerFactory: providerFactory
        )
    }
}
