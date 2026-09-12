@MainActor
protocol AnalyticsClient: Sendable {
    func track(_ event: AnalyticsEvent)
}

@MainActor
struct NoOpAnalyticsClient: AnalyticsClient {
    func track(_ event: AnalyticsEvent) { }
}
