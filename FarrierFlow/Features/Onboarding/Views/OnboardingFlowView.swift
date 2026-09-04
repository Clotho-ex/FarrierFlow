import SwiftUI

enum OnboardingBriefingRevealStep: Int, CaseIterable {
    case mark
    case brand
    case tagline
    case workflowTitle
    case appointment
    case visit
    case invoice
    case payment
    case continueAction

    var producesHaptic: Bool {
        self == .continueAction
    }
}

struct OnboardingFlowView: View {
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var brandTitleSize = 48

    @Bindable var model: OnboardingExperienceModel
    @Bindable var setupModel: OwnerSetupReadinessModel
    @State private var path: [OnboardingRoute]
    @State private var revealedBriefingStep: OnboardingBriefingRevealStep = .mark
    @State private var isBriefingContinueEnabled = false

    init(
        model: OnboardingExperienceModel,
        setupModel: OwnerSetupReadinessModel
    ) {
        self.model = model
        self.setupModel = setupModel
        _path = State(initialValue: model.navigationPath)
    }

    var body: some View {
        NavigationStack(path: $path) {
            rootContent
                .navigationDestination(for: OnboardingRoute.self) { route in
                    destination(for: route)
                }
        }
        .onChange(of: model.step) {
            let resolvedPath = model.navigationPath
            if path != resolvedPath {
                path = resolvedPath
            }
        }
        .onChange(of: path) { _, newPath in
            model.navigationPathDidChange(newPath)
        }
        .onChange(of: subscription.access, initial: true) { _, access in
            model.subscriptionAccessDidChange(access)
        }
        .accessibilityIdentifier("onboarding-flow")
    }

    @ViewBuilder
    private var rootContent: some View {
        switch model.step {
        case .loading:
            ProgressView("Loading FarrierFlow…")
        case .completed:
            ProgressView("Opening FarrierFlow…")
        case .legacyWelcome, .business, .legacyWorkflow, .briefing, .subscription:
            briefing
        }
    }

    @ViewBuilder
    private func destination(for route: OnboardingRoute) -> some View {
        switch route {
        case .business:
            OwnerSetupView(model: setupModel) {
                model.businessSetupDidFinish(
                    hasValidBusinessProfile: setupModel.hasValidIdentity,
                    access: subscription.access
                )
            }
        case .subscription:
            SubscriptionView(presentation: .onboarding)
        }
    }

    private var briefing: some View {
        OnboardingPinnedTitleScrollView("FarrierFlow") {
            VStack(spacing: SpacingTokens.generous) {
                VStack(spacing: SpacingTokens.related) {
                    Image("FarrierFlowMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .accessibilityHidden(true)
                        .onboardingBriefingReveal(
                            .mark,
                            revealedStep: revealedBriefingStep,
                            reduceMotion: reduceMotion
                        )

                    Text("FarrierFlow")
                        .font(
                            .system(
                                size: brandTitleSize,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("onboarding-welcome")
                        .onboardingBriefingReveal(
                            .brand,
                            revealedStep: revealedBriefingStep,
                            reduceMotion: reduceMotion
                        )

                    Text("Run your business from the field.")
                        .font(.title2.weight(.regular))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .onboardingBriefingReveal(
                            .tagline,
                            revealedStep: revealedBriefingStep,
                            reduceMotion: reduceMotion
                        )
                }

                VStack(alignment: .leading, spacing: SpacingTokens.standard) {
                    Text("Keep every job connected.")
                        .font(.title3.weight(.semibold))
                        .onboardingBriefingReveal(
                            .workflowTitle,
                            revealedStep: revealedBriefingStep,
                            reduceMotion: reduceMotion
                        )

                    OnboardingWorkflowDirection(
                        revealedStep: revealedBriefingStep,
                        reduceMotion: reduceMotion
                    )
                }
                .padding(.top, SpacingTokens.related)
                .frame(maxWidth: 420, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            .padding(.top, 36)
            .padding(.bottom, 112)
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: continueFromBriefing) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .farrierFlowPrimaryAction()
            .controlSize(.large)
            .disabled(!isBriefingContinueEnabled)
            .accessibilityIdentifier("onboarding-briefing-continue")
            .onboardingBriefingReveal(
                .continueAction,
                revealedStep: revealedBriefingStep,
                reduceMotion: reduceMotion
            )
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .tint(ColorTokens.brandActionText)
        .task {
            await revealBriefing()
        }
        .sensoryFeedback(
            .impact(weight: .light),
            trigger: revealedBriefingStep
        ) { _, newStep in
            !reduceMotion && newStep.producesHaptic
        }
    }

    private func revealBriefing() async {
        if reduceMotion {
            revealedBriefingStep = .continueAction
            isBriefingContinueEnabled = true
            return
        }
        guard revealedBriefingStep == .mark else { return }

        for step in OnboardingBriefingRevealStep.allCases.dropFirst() {
            do {
                try await Task.sleep(for: .milliseconds(80))
            } catch {
                return
            }
            withAnimation(.easeOut(duration: 0.24)) {
                revealedBriefingStep = step
            }
        }
        do {
            try await Task.sleep(for: .milliseconds(240))
        } catch {
            return
        }
        isBriefingContinueEnabled = true
    }

    private func continueFromBriefing() {
        model.briefingDidFinish()
    }
}

private struct OnboardingWorkflowDirection: View {
    let revealedStep: OnboardingBriefingRevealStep
    let reduceMotion: Bool

    private let stages: [Stage] = [
        .init(
            id: 1,
            title: "Appointment",
            detail: "Plan the next stop.",
            symbol: "calendar",
            revealStep: .appointment
        ),
        .init(
            id: 2,
            title: "Visit",
            detail: "Capture the work.",
            symbol: "figure.equestrian.sports",
            revealStep: .visit
        ),
        .init(
            id: 3,
            title: "Invoice",
            detail: "Bill while it’s fresh.",
            symbol: "doc.text",
            revealStep: .invoice
        ),
        .init(
            id: 4,
            title: "Payment",
            detail: "Know what’s settled.",
            symbol: "checkmark.circle",
            revealStep: .payment
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stages.enumerated()), id: \.element.id) { index, stage in
                stageView(
                    stage,
                    position: index + 1,
                    isLast: index == stages.count - 1
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func stageView(
        _ stage: Stage,
        position: Int,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: stage.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)

                if !isLast {
                    Rectangle()
                        .fill(ColorTokens.border)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(stage.title)
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)

                Text(stage.detail)
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .padding(.top, 6)
            .padding(.bottom, isLast ? 0 : 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onboardingBriefingReveal(
            stage.revealStep,
            revealedStep: revealedStep,
            reduceMotion: reduceMotion
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(stage.title). \(stage.detail) \(position) of \(stages.count)."
        )
        .accessibilityIdentifier("onboarding-workflow-\(stage.identifier)")
    }
}

private extension OnboardingWorkflowDirection {
    struct Stage: Identifiable {
        let id: Int
        let title: LocalizedStringResource
        let detail: LocalizedStringResource
        let symbol: String
        let revealStep: OnboardingBriefingRevealStep

        var identifier: String {
            switch id {
            case 1: "appointment"
            case 2: "visit"
            case 3: "invoice"
            default: "payment"
            }
        }
    }
}
