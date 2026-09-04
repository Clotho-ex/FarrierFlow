import Foundation
import Testing
@testable import FarrierFlow

@Suite("Onboarding experience")
@MainActor
struct OnboardingExperienceModelTests {
    @Test
    func freshInstallStartsWithTheProductBriefingAndResumesIt() throws {
        try withDefaults { defaults in
            let firstLaunch = OnboardingExperienceModel(defaults: defaults)

            firstLaunch.resolve(hasValidBusinessProfile: false)
            #expect(firstLaunch.step == .briefing)
            #expect(firstLaunch.navigationPath == [])

            let interruptedLaunch = OnboardingExperienceModel(defaults: defaults)
            interruptedLaunch.resolve(hasValidBusinessProfile: false)
            #expect(interruptedLaunch.step == .briefing)
        }
    }

    @Test
    func navigationPathReconstructsEveryResumableStep() throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(hasValidBusinessProfile: false)
            #expect(model.navigationPath == [])

            model.briefingDidFinish()
            #expect(model.navigationPath == [.business])

            model.businessSetupDidFinish(
                hasValidBusinessProfile: true,
                access: .free
            )
            #expect(model.navigationPath == [.business, .subscription])
        }
    }

    @Test
    func sameVersionRelaunchReconstructsEveryInterruptedStage() throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(hasValidBusinessProfile: false)

            var relaunched = OnboardingExperienceModel(defaults: defaults)
            relaunched.resolve(hasValidBusinessProfile: false)
            #expect(relaunched.navigationPath == [])

            model.briefingDidFinish()
            relaunched = OnboardingExperienceModel(defaults: defaults)
            relaunched.resolve(hasValidBusinessProfile: false)
            #expect(relaunched.navigationPath == [.business])

            model.businessSetupDidFinish(
                hasValidBusinessProfile: true,
                access: .free
            )
            relaunched = OnboardingExperienceModel(defaults: defaults)
            relaunched.resolve(hasValidBusinessProfile: true)
            #expect(relaunched.navigationPath == [.business, .subscription])
        }
    }

    @Test
    func nativeBackNavigationPersistsTheReturnedBusinessStep() throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(hasValidBusinessProfile: false)
            model.briefingDidFinish()
            model.businessSetupDidFinish(
                hasValidBusinessProfile: true,
                access: .free
            )

            model.navigationPathDidChange([.business])
            #expect(model.step == .business)

            model.navigationPathDidChange([])
            #expect(model.step == .briefing)

            let relaunched = OnboardingExperienceModel(defaults: defaults)
            relaunched.resolve(hasValidBusinessProfile: true)
            #expect(relaunched.step == .briefing)
            #expect(relaunched.navigationPath == [])
        }
    }

    @Test
    func sameVersionLegacyWorkflowStepResumesAtTheProductBriefing() throws {
        try withDefaults { defaults in
            defaults.set("workflow", forKey: "onboarding.currentStep")
            defaults.set(1, forKey: "onboarding.inProgressVersion")

            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(hasValidBusinessProfile: true)

            #expect(model.step == .briefing)
            #expect(model.navigationPath == [])
        }
    }

    @Test
    func legacyWorkflowStepWithoutAValidBusinessRestartsAtTheProductBriefing() throws {
        try withDefaults { defaults in
            defaults.set("workflow", forKey: "onboarding.currentStep")
            defaults.set(1, forKey: "onboarding.inProgressVersion")

            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(hasValidBusinessProfile: false)

            #expect(model.step == .briefing)
            #expect(model.navigationPath == [])
        }
    }

    @Test
    func staleUnversionedSubscriptionStepRestartsAtTheProductBriefing() throws {
        try withDefaults { defaults in
            defaults.set("subscription", forKey: "onboarding.currentStep")

            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(hasValidBusinessProfile: true)

            #expect(model.step == .briefing)
        }
    }

    @Test
    func savedBusinessProfileDoesNotSkipAnExplicitBusinessStep() throws {
        try withDefaults { defaults in
            let firstLaunch = OnboardingExperienceModel(defaults: defaults)
            firstLaunch.resolve(hasValidBusinessProfile: false)
            firstLaunch.briefingDidFinish()

            let interruptedLaunch = OnboardingExperienceModel(defaults: defaults)
            interruptedLaunch.resolve(hasValidBusinessProfile: true)

            #expect(interruptedLaunch.step == .business)
        }
    }

    @Test
    func existingConfiguredWorkspaceBypassesNewOnboarding() throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)

            model.resolve(hasValidBusinessProfile: true)

            #expect(model.step == .completed)
            let relaunched = OnboardingExperienceModel(defaults: defaults)
            relaunched.resolve(hasValidBusinessProfile: true)
            #expect(relaunched.step == .completed)
        }
    }

    @Test
    func existingBusinessDataBypassesNewOnboardingWithoutAValidProfile() throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)

            model.resolve(
                hasValidBusinessProfile: false,
                hasExistingBusinessData: true
            )

            #expect(model.step == .completed)
        }
    }

    @Test
    func briefingAlwaysLeadsToBusinessPersonalization() throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(hasValidBusinessProfile: false)

            model.briefingDidFinish()

            #expect(model.step == .business)
            #expect(model.navigationPath == [.business])
        }
    }

    @Test(arguments: [SubscriptionAccess.loading, .free, .unavailable])
    func businessSetupRequiresThePaywallForEveryNonProState(
        access: SubscriptionAccess
    ) throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(hasValidBusinessProfile: false)
            model.briefingDidFinish()
            model.businessSetupDidFinish(
                hasValidBusinessProfile: true,
                access: access
            )

            #expect(model.step == .subscription)
            #expect(model.navigationPath == [.business, .subscription])

            model.subscriptionAccessDidChange(access)
            #expect(model.step == .subscription)
        }
    }

    @Test
    func existingProCompletesWithoutRedundantPurchaseStep() throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(hasValidBusinessProfile: false)
            model.briefingDidFinish()
            model.businessSetupDidFinish(
                hasValidBusinessProfile: true,
                access: .pro
            )

            #expect(model.step == .completed)
        }
    }

    @Test
    func restoredProCompletesTheSubscriptionStep() throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(hasValidBusinessProfile: false)
            model.briefingDidFinish()
            model.businessSetupDidFinish(
                hasValidBusinessProfile: true,
                access: .free
            )

            model.subscriptionAccessDidChange(.pro)

            #expect(model.step == .completed)
        }
    }

    @Test
    func unavailableSubscriptionServiceKeepsTheSavedBusinessAtThePaywall() throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(hasValidBusinessProfile: false)
            model.briefingDidFinish()
            model.businessSetupDidFinish(
                hasValidBusinessProfile: true,
                access: .unavailable
            )

            #expect(model.step == .subscription)

            let relaunched = OnboardingExperienceModel(defaults: defaults)
            relaunched.resolve(hasValidBusinessProfile: true)
            #expect(relaunched.step == .subscription)
            #expect(relaunched.navigationPath == [.business, .subscription])
        }
    }

    @Test
    func completedVersionRemainsIndependentFromBusinessRecords() throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(hasValidBusinessProfile: false)
            model.briefingDidFinish()
            model.businessSetupDidFinish(
                hasValidBusinessProfile: true,
                access: .pro
            )

            let relaunched = OnboardingExperienceModel(defaults: defaults)
            relaunched.resolve(hasValidBusinessProfile: false)

            #expect(relaunched.step == .completed)
        }
    }

    @Test
    func paymentHintIsShownOnlyUntilItsFirstUse() throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)
            #expect(model.showsPaymentRecordingHint)

            model.markPaymentRecordingHintSeen()

            #expect(!model.showsPaymentRecordingHint)
            let relaunched = OnboardingExperienceModel(defaults: defaults)
            #expect(!relaunched.showsPaymentRecordingHint)
        }
    }

    @Test
    func invoiceHintIsShownOnlyUntilItsFirstUse() throws {
        try withDefaults { defaults in
            let model = OnboardingExperienceModel(defaults: defaults)
            #expect(model.showsInvoiceCreationHint)

            model.markInvoiceCreationHintSeen()

            #expect(!model.showsInvoiceCreationHint)
            let relaunched = OnboardingExperienceModel(defaults: defaults)
            #expect(!relaunched.showsInvoiceCreationHint)
        }
    }

    private func withDefaults(
        _ body: (UserDefaults) throws -> Void
    ) throws {
        let suiteName = "OnboardingExperienceModelTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try body(defaults)
    }
}
