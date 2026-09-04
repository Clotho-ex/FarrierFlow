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
    static let colorSchemeEnvironmentKey =
        "FARRIERFLOW_UI_TEST_COLOR_SCHEME"
    static let subscriptionAccessEnvironmentKey =
        "FARRIERFLOW_UI_TEST_SUBSCRIPTION_ACCESS"

    let storeURL: URL?
    let forcesCameraUnavailable: Bool
    let scenario: UITestScenario?
    let dynamicTypeSize: DynamicTypeSize?
    let colorScheme: ColorScheme?
    let subscriptionAccess: SubscriptionUITestAccess

    var onboardingDefaults: UserDefaults {
        guard let storeURL else { return .standard }
        let suiteName = "FarrierFlow.UITests.\(storeURL.deletingPathExtension().lastPathComponent)"
        return UserDefaults(suiteName: suiteName) ?? .standard
    }

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
        colorScheme = switch processInfo.environment[
            Self.colorSchemeEnvironmentKey
        ] {
        case "dark":
            .dark
        case "light":
            .light
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
    case purchaseCancellation = "purchase-cancellation"
    case purchaseFailure = "purchase-failure"
    case restoreSuccess = "restore-success"
    case noTrial = "no-trial"
    case outage
    case updatePro = "update-pro"
}

nonisolated private enum SubscriptionUITestError: Error { case expected }

@MainActor
struct UITestSubscriptionClient: SubscriptionClient {
    let configuration: UITestLaunchConfiguration

    func customerInfo() async throws -> SubscriptionCustomerSnapshot {
        if configuration.subscriptionAccess == .outage {
            throw SubscriptionUITestError.expected
        }
        return .init(hasActiveProEntitlement: configuration.subscriptionAccess == .full)
    }

    func offerings() async throws -> [SubscriptionPlan] {
        if configuration.subscriptionAccess == .outage {
            throw SubscriptionUITestError.expected
        }
        let trial: SubscriptionTrial? = configuration.subscriptionAccess == .noTrial
            ? nil
            : .init(duration: 2, unit: .week)
        return [
            .init(
                id: "annual",
                productID: SubscriptionProduct.yearly,
                kind: .annual,
                displayName: "Annual",
                localizedPrice: "$119.99",
                localizedMonthlyEquivalent: "$10.00",
                price: Decimal(string: "119.99"),
                currencyCode: "USD",
                subscriptionPeriod: "year",
                introductoryTrial: trial
            ),
            .init(
                id: "monthly",
                productID: SubscriptionProduct.monthly,
                kind: .monthly,
                displayName: "Monthly",
                localizedPrice: "$14.99",
                price: Decimal(string: "14.99"),
                currencyCode: "USD",
                subscriptionPeriod: "month",
                introductoryTrial: trial
            ),
        ]
    }

    func purchase(planID: String) async throws -> SubscriptionPurchaseResult {
        switch configuration.subscriptionAccess {
        case .purchaseCancellation:
            .init(customer: .init(hasActiveProEntitlement: false), wasCancelled: true)
        case .purchaseFailure:
            throw SubscriptionUITestError.expected
        default:
            .init(customer: .init(hasActiveProEntitlement: true), wasCancelled: false)
        }
    }

    func restorePurchases() async throws -> SubscriptionCustomerSnapshot {
        .init(hasActiveProEntitlement: true)
    }

    func customerInfoUpdates() async -> AsyncStream<SubscriptionCustomerSnapshot> {
        let emitsPro = configuration.subscriptionAccess == .updatePro
        return AsyncStream { continuation in
            if emitsPro {
                continuation.yield(.init(hasActiveProEntitlement: true))
            }
            continuation.finish()
        }
    }
}
#endif
