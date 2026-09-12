import SwiftUI

extension EnvironmentValues {
    @Entry var analyticsClient: any AnalyticsClient = NoOpAnalyticsClient()
}
