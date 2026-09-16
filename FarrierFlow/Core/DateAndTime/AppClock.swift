import Foundation
import SwiftUI

nonisolated struct AppClock: Sendable {
    private let nowProvider: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date) {
        nowProvider = now
    }

    func now() -> Date {
        nowProvider()
    }

    static var system: AppClock {
        AppClock(now: { Date.now })
    }

    static func fixed(_ date: Date) -> AppClock {
        AppClock(now: { date })
    }
}

extension EnvironmentValues {
    @Entry var appClock: AppClock = .system
}
