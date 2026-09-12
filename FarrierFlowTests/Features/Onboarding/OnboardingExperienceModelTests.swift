import Foundation
import Testing
@testable import FarrierFlow

@Suite("Onboarding experience")
@MainActor
struct OnboardingExperienceModelTests {
    @Test
    func freshOnboardingStartEmitsOnceAcrossResolutionAndReconstruction() throws {
        try withDefaults { defaults in
            let analytics = AnalyticsSpy()
            let firstLaunch = OnboardingExperienceModel(defaults: defaults)

            firstLaunch.resolve(
                hasValidBusinessProfile: false,
                analyticsClient: analytics
            )
            firstLaunch.resolve(
                hasValidBusinessProfile: false,
                analyticsClient: analytics
            )
            #expect(defaults.string(forKey: "onboarding.currentStep") == "briefing")

            let reconstructed = OnboardingExperienceModel(defaults: defaults)
            reconstructed.resolve(
                hasValidBusinessProfile: false,
                analyticsClient: analytics
            )
            reconstructed.subscriptionAccessDidChange(
                .pro,
                analyticsClient: analytics
            )
            reconstructed.navigationPathDidChange(reconstructed.navigationPath)

            let relaunched = OnboardingExperienceModel(defaults: defaults)
            relaunched.resolve(
                hasValidBusinessProfile: false,
                analyticsClient: analytics
            )

            #expect(firstLaunch.step == .briefing)
            #expect(reconstructed.step == .briefing)
            #expect(relaunched.step == .briefing)
            #expect(analytics.events == [.onboardingStarted])
        }
    }

    @Test
    func existingWorkspaceBypassDoesNotReportOnboardingStartedOrCompleted() throws {
        try withDefaults { defaults in
            let analytics = AnalyticsSpy()
            let model = OnboardingExperienceModel(defaults: defaults)

            model.resolve(
                hasValidBusinessProfile: true,
                analyticsClient: analytics
            )

            #expect(model.step == .completed)
            #expect(analytics.events.isEmpty)
        }
    }

    @Test
    func proBusinessCompletionReportsOnboardingCompletedOnce() throws {
        try withDefaults { defaults in
            let analytics = AnalyticsSpy()
            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(
                hasValidBusinessProfile: false,
                analyticsClient: analytics
            )
            model.briefingDidFinish()

            model.businessSetupDidFinish(
                hasValidBusinessProfile: true,
                access: .pro,
                analyticsClient: analytics
            )
            model.businessSetupDidFinish(
                hasValidBusinessProfile: true,
                access: .pro,
                analyticsClient: analytics
            )

            #expect(model.step == .completed)
            #expect(analytics.events == [.onboardingStarted, .onboardingCompleted])
        }
    }

    @Test
    func subscriptionCompletionReportsOnboardingCompletedOnce() throws {
        try withDefaults { defaults in
            let analytics = AnalyticsSpy()
            let model = OnboardingExperienceModel(defaults: defaults)
            model.resolve(
                hasValidBusinessProfile: false,
                analyticsClient: analytics
            )
            model.briefingDidFinish()
            model.businessSetupDidFinish(
                hasValidBusinessProfile: true,
                access: .free,
                analyticsClient: analytics
            )

            model.subscriptionAccessDidChange(.pro, analyticsClient: analytics)
            model.subscriptionAccessDidChange(.pro, analyticsClient: analytics)

            #expect(model.step == .completed)
            #expect(analytics.events == [.onboardingStarted, .onboardingCompleted])
        }
    }

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
