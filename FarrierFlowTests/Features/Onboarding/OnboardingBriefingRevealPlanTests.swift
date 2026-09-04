import Testing
@testable import FarrierFlow

@Suite("Onboarding briefing reveal plan")
@MainActor
struct OnboardingBriefingRevealPlanTests {
    @Test
    func revealsTheBriefingFromBrandThroughAction() {
        #expect(
            OnboardingBriefingRevealStep.allCases == [
                .mark,
                .brand,
                .tagline,
                .workflowTitle,
                .appointment,
                .visit,
                .invoice,
                .payment,
                .continueAction,
            ]
        )
    }

    @Test
    func onlyRevealCompletionProducesAutomaticHapticFeedback() {
        let hapticSteps = OnboardingBriefingRevealStep.allCases.filter(\.producesHaptic)

        #expect(hapticSteps == [.continueAction])
    }
}
