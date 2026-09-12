import Foundation

nonisolated enum PostHogAnalyticsConfigurationError: Error, Equatable, Sendable {
    case missingProjectToken
    case invalidProjectToken
    case missingHost
    case invalidHost

    var diagnosticDescription: String {
        switch self {
        case .missingProjectToken: "PostHog project token is missing."
        case .invalidProjectToken: "PostHog project token is malformed."
        case .missingHost: "PostHog ingestion host is missing."
        case .invalidHost: "PostHog ingestion host must be a valid HTTPS origin."
        }
    }
}

nonisolated struct PostHogAnalyticsConfiguration: Equatable, Sendable {
    static let projectTokenInfoKey = "PostHogProjectToken"
    static let hostInfoKey = "PostHogHost"

    let projectToken: String
    let host: URL

    init(infoDictionary: [String: Any]) throws {
        guard let rawToken = infoDictionary[Self.projectTokenInfoKey] as? String,
              !rawToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PostHogAnalyticsConfigurationError.missingProjectToken
        }
        let projectToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard projectToken.hasPrefix("phc_"), projectToken.count > 4 else {
            throw PostHogAnalyticsConfigurationError.invalidProjectToken
        }

        guard let rawHost = infoDictionary[Self.hostInfoKey] as? String,
              !rawHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PostHogAnalyticsConfigurationError.missingHost
        }
        let hostString = rawHost.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: hostString),
              components.scheme == "https",
              components.host != nil,
              components.path.isEmpty || components.path == "/",
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              let host = components.url else {
            throw PostHogAnalyticsConfigurationError.invalidHost
        }

        self.projectToken = projectToken
        self.host = host
    }
}
