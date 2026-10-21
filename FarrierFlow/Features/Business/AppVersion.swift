import Foundation

nonisolated struct AppVersion: Equatable {
    let version: String?
    let build: String?

    static var installed: AppVersion { AppVersion(infoDictionary: Bundle.main.infoDictionary ?? [:]) }

    init(infoDictionary: [String: Any]) {
        version = (infoDictionary["CFBundleShortVersionString"] as? String).flatMap(TextNormalization.required)
        build = (infoDictionary["CFBundleVersion"] as? String).flatMap(TextNormalization.required)
    }

    var displayText: String {
        guard let version else { return String(localized: "Version unavailable") }
        if let build {
            return String(localized: "Version \(version) (\(build))")
        }
        return String(localized: "Version \(version)")
    }
}
