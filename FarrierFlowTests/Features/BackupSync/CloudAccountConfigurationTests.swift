import Foundation
import Testing
@testable import FarrierFlow

@Suite("Cloud client configuration")
struct CloudAccountConfigurationTests {
    #if DEBUG
    @Test
    func debugHostIncludesApprovedDevelopmentClientConfiguration() throws {
        let info = try #require(Bundle.main.infoDictionary)
        let configuration = try SupabaseConfiguration(infoDictionary: info)
        #expect(configuration.url.host == "xufledziawaapvrifbfv.supabase.co")
        #expect(configuration.publishableKey.hasPrefix("sb_publishable_"))
    }
    #endif

    @Test
    func acceptsOnlyAPublicClientKeyAndHTTPSProjectURL() throws {
        let configuration = try SupabaseConfiguration(infoDictionary: [
            "SUPABASE_URL": "https://xufledziawaapvrifbfv.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_" + String(repeating: "x", count: 32),
        ])
        #expect(configuration.url.host == "xufledziawaapvrifbfv.supabase.co")
    }

    @Test(arguments: [
        "http://xufledziawaapvrifbfv.supabase.co",
        "https://example.com",
        "https://user:password@xufledziawaapvrifbfv.supabase.co",
        "https://xufledziawaapvrifbfv.supabase.co/?secret=value",
        "$(SUPABASE_URL)",
    ])
    func rejectsUnsafeOrUnexpandedURLs(_ url: String) {
        #expect(throws: SupabaseConfigurationError.invalidURL) {
            try SupabaseConfiguration(infoDictionary: [
                "SUPABASE_URL": url,
                "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_" + String(repeating: "x", count: 32),
            ])
        }
    }

    @Test(arguments: [
        "sb_secret_" + String(repeating: "x", count: 32),
        "legacy-service-role-jwt",
        "$(SUPABASE_PUBLISHABLE_KEY)",
    ])
    func refusesPrivilegedKeysInTheApp(_ key: String) {
        #expect(throws: SupabaseConfigurationError.invalidPublishableKey) {
            try SupabaseConfiguration(infoDictionary: [
                "SUPABASE_URL": "https://xufledziawaapvrifbfv.supabase.co",
                "SUPABASE_PUBLISHABLE_KEY": key,
            ])
        }
    }

    @Test
    func missingConfigurationDoesNotInventCredentials() {
        #expect(throws: SupabaseConfigurationError.missingURL) {
            try SupabaseConfiguration(infoDictionary: [:])
        }
    }

    @Test
    func cloudDeletionStaysOffWithoutExplicitConfiguration() throws {
        let configuration = try developmentConfiguration()
        #expect(!configuration.cloudDeletionIsAvailable(infoDictionary: [:], environment: [:]))
        #expect(!configuration.cloudDeletionIsAvailable(
            infoDictionary: ["SUPABASE_CLOUD_DELETION_ENABLED": "true"], environment: [:]))
        #expect(configuration.cloudDeletionIsAvailable(
            infoDictionary: ["SUPABASE_CLOUD_DELETION_ENABLED": true], environment: [:]))
    }

    @Test
    func devDeletionOverrideRequiresDebugCompilation() throws {
        let configuration = try developmentConfiguration()
        let available = configuration.cloudDeletionIsAvailable(infoDictionary: [:],
            environment: ["FARRIERFLOW_DEV_CLOUD_DELETION_TEST": "1"])
        #if DEBUG
        #expect(available)
        #else
        #expect(!available)
        #endif
    }

    @Test(arguments: ["", "0", "true", "yes"])
    func devDeletionOverrideRequiresExactOptIn(_ value: String) throws {
        let configuration = try developmentConfiguration()
        #expect(!configuration.cloudDeletionIsAvailable(infoDictionary: [:],
            environment: ["FARRIERFLOW_DEV_CLOUD_DELETION_TEST": value]))
    }

    @Test
    func devDeletionOverrideCannotEnableAnotherProject() throws {
        let configuration = try SupabaseConfiguration(infoDictionary: [
            "SUPABASE_URL": "https://anotherproject.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_" + String(repeating: "x", count: 32),
        ])
        #expect(!configuration.cloudDeletionIsAvailable(infoDictionary: [:],
            environment: ["FARRIERFLOW_DEV_CLOUD_DELETION_TEST": "1"]))
    }

    private func developmentConfiguration() throws -> SupabaseConfiguration {
        try SupabaseConfiguration(infoDictionary: [
            "SUPABASE_URL": "https://xufledziawaapvrifbfv.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_" + String(repeating: "x", count: 32),
        ])
    }
}
