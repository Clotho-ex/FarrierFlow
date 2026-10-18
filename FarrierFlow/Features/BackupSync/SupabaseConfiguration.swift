import Foundation

nonisolated enum SupabaseConfigurationError: Error, Equatable {
    case missingURL
    case invalidURL
    case missingPublishableKey
    case invalidPublishableKey
}

nonisolated struct SupabaseConfiguration: Sendable {
    let url: URL
    let publishableKey: String

    func cloudDeletionIsAvailable(infoDictionary: [String: Any],
                                  environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        if infoDictionary["SUPABASE_CLOUD_DELETION_ENABLED"] as? Bool == true { return true }
        #if DEBUG
        // Acceptance testing must not enable deletion for another project or Release.
        return url.host == "xufledziawaapvrifbfv.supabase.co" &&
            environment["FARRIERFLOW_DEV_CLOUD_DELETION_TEST"] == "1"
        #else
        return false
        #endif
    }

    init(infoDictionary: [String: Any]) throws {
        guard let urlString = infoDictionary["SUPABASE_URL"] as? String,
              !urlString.isEmpty else { throw SupabaseConfigurationError.missingURL }
        guard let components = URLComponents(string: urlString),
              components.scheme == "https",
              let host = components.host, host.hasSuffix(".supabase.co"),
              host.split(separator: ".").count == 3,
              components.user == nil, components.password == nil,
              components.port == nil, components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              let url = components.url else {
            throw SupabaseConfigurationError.invalidURL
        }
        guard let key = infoDictionary["SUPABASE_PUBLISHABLE_KEY"] as? String,
              !key.isEmpty else { throw SupabaseConfigurationError.missingPublishableKey }
        guard key.hasPrefix("sb_publishable_"), key.count >= 30,
              key.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else {
            throw SupabaseConfigurationError.invalidPublishableKey
        }
        self.url = url
        publishableKey = key
    }
}
