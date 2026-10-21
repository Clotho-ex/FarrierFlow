@MainActor
protocol AnalyticsClient: Sendable {
    func start()
    func track(_ event: AnalyticsEvent)
}

extension AnalyticsClient {
    func start() { }
}

@MainActor
struct NoOpAnalyticsClient: AnalyticsClient {
    func track(_ event: AnalyticsEvent) { }
}
