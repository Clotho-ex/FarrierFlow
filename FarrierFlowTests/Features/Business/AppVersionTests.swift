import Testing
@testable import FarrierFlow

@Suite("Installed app version")
struct AppVersionTests {
    @Test func usesInstalledVersionAndBuild() {
        let version = AppVersion(infoDictionary: ["CFBundleShortVersionString": "1.2.3", "CFBundleVersion": "456"])
        #expect(version.version == "1.2.3")
        #expect(version.build == "456")
        #expect(version.displayText.contains("1.2.3"))
        #expect(version.displayText.contains("456"))
    }

    @Test func missingBuildDoesNotInventOne() {
        let version = AppVersion(infoDictionary: ["CFBundleShortVersionString": " 1.2.3 ", "CFBundleVersion": " "])
        #expect(version.version == "1.2.3")
        #expect(version.build == nil)
        #expect(version.displayText.contains("1.2.3"))
        #expect(!version.displayText.contains("("))
    }

    @Test func missingVersionDoesNotInventOne() {
        let version = AppVersion(infoDictionary: ["CFBundleShortVersionString": " ", "CFBundleVersion": 456])
        #expect(version.version == nil)
        #expect(version.build == nil)
        #expect(!version.displayText.isEmpty)
    }
}
