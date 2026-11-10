nonisolated enum InputLimits {
    static let name = 60
    static let phone = 25
    static let email = 100
    static let address = 200
    static let notes = 500
    static let reference = 100
    static let price = 16
    static let duration = 4

    static func fits(_ value: String, maximum: Int) -> Bool {
        value.count <= maximum
    }

    static func accepting(_ value: String, previous: String, maximum: Int, rejectOverflow: Bool = false) -> String {
        guard value.count > maximum else { return value }
        // Loading an older record must never discard its saved text. Allow it to be shortened.
        if previous.count > maximum {
            return value.count <= previous.count ? value : previous
        }
        return rejectOverflow ? previous : String(value.prefix(maximum))
    }
}
