@testable import FarrierFlow

@MainActor
final class AnalyticsSpy: AnalyticsClient {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}
