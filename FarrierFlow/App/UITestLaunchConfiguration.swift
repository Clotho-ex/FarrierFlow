#if DEBUG
import Foundation
import SwiftData

struct UITestLaunchConfiguration {
    static let storeNameEnvironmentKey = "FARRIERFLOW_UI_TEST_STORE"
    static let cameraUnavailableEnvironmentKey =
        "FARRIERFLOW_UI_TEST_CAMERA_UNAVAILABLE"
    static let scenarioEnvironmentKey = "FARRIERFLOW_UI_TEST_SCENARIO"

    let storeURL: URL?
    let forcesCameraUnavailable: Bool
    let scenario: UITestScenario?

    init(processInfo: ProcessInfo = .processInfo) {
        forcesCameraUnavailable =
            processInfo.environment[Self.cameraUnavailableEnvironmentKey] == "1"
        scenario = processInfo.environment[Self.scenarioEnvironmentKey]
            .flatMap(UITestScenario.init(rawValue:))
        guard let rawName = processInfo.environment[Self.storeNameEnvironmentKey] else {
            storeURL = nil
            return
        }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = rawName.unicodeScalars
            .filter(allowed.contains)
            .map(String.init)
            .joined()

        guard !sanitized.isEmpty else {
            storeURL = nil
            return
        }

        let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        storeURL = support
            .appending(path: "UITests", directoryHint: .isDirectory)
            .appending(path: "\(sanitized).store")
    }

    @MainActor
    func prepare(_ container: ModelContainer) throws {
        guard let storeURL else { return }
        if let scenario {
            try UITestFixtures.seed(
                scenario,
                in: container,
                photographRootURL: storeURL
                    .deletingPathExtension()
                    .appending(
                        path: PhotographConstants.rootDirectoryName,
                        directoryHint: .isDirectory
                    )
            )
        } else {
            try UITestFixtures.seedOwnerIdentity(in: container)
        }
    }
}

enum UITestScenario: String {
    case invoiceReady = "invoice-ready"
    case ownerSetup = "owner-setup"
}
#endif
