#if DEBUG
import Foundation
import SwiftData
import SwiftUI

struct UITestLaunchConfiguration {
    static let storeNameEnvironmentKey = "FARRIERFLOW_UI_TEST_STORE"
    static let cameraUnavailableEnvironmentKey =
        "FARRIERFLOW_UI_TEST_CAMERA_UNAVAILABLE"
    static let scenarioEnvironmentKey = "FARRIERFLOW_UI_TEST_SCENARIO"
    static let dynamicTypeSizeEnvironmentKey =
        "FARRIERFLOW_UI_TEST_DYNAMIC_TYPE_SIZE"
    static let subscriptionAccessEnvironmentKey =
        "FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"

    let storeURL: URL?
    let forcesCameraUnavailable: Bool
    let scenario: UITestScenario?
    let dynamicTypeSize: DynamicTypeSize?
    let subscriptionAccess: SubscriptionUITestAccess

    init(processInfo: ProcessInfo = .processInfo) {
        forcesCameraUnavailable =
            processInfo.environment[Self.cameraUnavailableEnvironmentKey] == "1"
        scenario = processInfo.environment[Self.scenarioEnvironmentKey]
            .flatMap(UITestScenario.init(rawValue:))
        dynamicTypeSize = switch processInfo.environment[
            Self.dynamicTypeSizeEnvironmentKey
        ] {
        case "accessibility5":
            .accessibility5
        default:
            nil
        }
        subscriptionAccess = processInfo.environment[
            Self.subscriptionAccessEnvironmentKey
        ]
        .flatMap(SubscriptionUITestAccess.init(rawValue:)) ?? .full
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
    case paymentPending = "payment-pending"
    case nextAppointment = "next-appointment"
    case ownerSetup = "owner-setup"
}

nonisolated enum SubscriptionUITestAccess: String, Sendable {
    case full
    case readOnly = "read-only"
}

nonisolated struct UITestSubscriptionEntitlementSource:
    SubscriptionEntitlementSource {
    let access: SubscriptionUITestAccess

    func hasCurrentEntitlement(productIDs: Set<String>) async -> Bool {
        access == .full
    }

    func updates(productIDs: Set<String>) async -> AsyncStream<Void> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
#endif
