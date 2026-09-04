import Foundation
import Observation

nonisolated enum OnboardingStep: String, Equatable, Sendable {
    case loading
    case legacyWelcome = "welcome"
    case business
    case legacyWorkflow = "workflow"
    case briefing
    case subscription
    case completed
}

nonisolated enum OnboardingRoute: Hashable, Sendable {
    case business
    case subscription
}

@MainActor
@Observable
final class OnboardingExperienceModel {
    static let currentVersion = 1

    private enum Key {
        static let completedVersion = "onboarding.completedVersion"
        static let inProgressVersion = "onboarding.inProgressVersion"
        static let currentStep = "onboarding.currentStep"
        static let invoiceHintSeen = "onboarding.invoiceHintSeen"
        static let paymentHintSeen = "onboarding.paymentHintSeen"
    }

    private let defaults: UserDefaults

    private(set) var step: OnboardingStep = .loading
    private(set) var showsInvoiceCreationHint: Bool
    private(set) var showsPaymentRecordingHint: Bool

    var navigationPath: [OnboardingRoute] {
        Self.navigationPath(for: step)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showsInvoiceCreationHint = !defaults.bool(forKey: Key.invoiceHintSeen)
        showsPaymentRecordingHint = !defaults.bool(forKey: Key.paymentHintSeen)
    }

    func resolve(
        hasValidBusinessProfile: Bool,
        hasExistingBusinessData: Bool = false
    ) {
        let completedVersion = defaults.integer(forKey: Key.completedVersion)
        if completedVersion >= Self.currentVersion {
            step = .completed
            return
        }

        let persistedStep = defaults.string(forKey: Key.currentStep)
            .flatMap(OnboardingStep.init(rawValue:))

        if persistedStep != nil,
           defaults.integer(forKey: Key.inProgressVersion) != Self.currentVersion {
            defaults.removeObject(forKey: Key.currentStep)
            defaults.removeObject(forKey: Key.inProgressVersion)
            persist(.briefing)
            return
        }

        if completedVersion == 0,
           persistedStep == nil,
           (hasValidBusinessProfile || hasExistingBusinessData) {
            complete()
            return
        }

        switch persistedStep {
        case .legacyWelcome:
            persist(.briefing)
        case .subscription where !hasValidBusinessProfile:
            persist(.business)
        case .legacyWorkflow:
            persist(.briefing)
        case .business, .briefing, .subscription:
            step = persistedStep ?? .business
        case .completed:
            complete()
        default:
            persist(.briefing)
        }
    }

    func businessSetupDidFinish(
        hasValidBusinessProfile: Bool,
        access: SubscriptionAccess
    ) {
        guard step == .business, hasValidBusinessProfile else { return }
        if access == .pro {
            complete()
        } else {
            persist(.subscription)
        }
    }

    func briefingDidFinish() {
        guard step == .briefing else { return }
        persist(.business)
    }

    func subscriptionAccessDidChange(_ access: SubscriptionAccess) {
        guard step == .subscription, access == .pro else { return }
        complete()
    }

    func navigationPathDidChange(_ path: [OnboardingRoute]) {
        let returnedStep: OnboardingStep = switch path.last {
        case .business:
            .business
        case .subscription:
            .subscription
        case nil:
            .briefing
        }
        let returnedPath = Self.navigationPath(for: returnedStep)
        guard path == returnedPath,
              returnedPath.count < navigationPath.count else {
            return
        }
        persist(returnedStep)
    }

    func markPaymentRecordingHintSeen() {
        guard showsPaymentRecordingHint else { return }
        defaults.set(true, forKey: Key.paymentHintSeen)
        showsPaymentRecordingHint = false
    }

    func markInvoiceCreationHintSeen() {
        guard showsInvoiceCreationHint else { return }
        defaults.set(true, forKey: Key.invoiceHintSeen)
        showsInvoiceCreationHint = false
    }

    private func persist(_ step: OnboardingStep) {
        defaults.set(Self.currentVersion, forKey: Key.inProgressVersion)
        defaults.set(step.rawValue, forKey: Key.currentStep)
        self.step = step
    }

    private static func navigationPath(
        for step: OnboardingStep
    ) -> [OnboardingRoute] {
        switch step {
        case .loading, .legacyWelcome, .legacyWorkflow, .briefing, .completed:
            []
        case .business:
            [.business]
        case .subscription:
            [.business, .subscription]
        }
    }

    private func complete() {
        defaults.set(Self.currentVersion, forKey: Key.completedVersion)
        defaults.removeObject(forKey: Key.currentStep)
        defaults.removeObject(forKey: Key.inProgressVersion)
        step = .completed
    }
}
