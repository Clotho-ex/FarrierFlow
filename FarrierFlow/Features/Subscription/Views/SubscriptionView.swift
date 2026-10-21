import StoreKit
import SwiftUI

private enum SubscriptionLayout {
    static let subtitleGap: CGFloat = 4
    static let rowGap: CGFloat = 8
    static let contentGap: CGFloat = 12
    static let sectionGap: CGFloat = 28
    static let cardRadius: CGFloat = 20
    static let symbolSide: CGFloat = 24
}

struct SubscriptionView: View {
    enum Presentation: Equatable {
        case standard(showsManageSubscriptionButton: Bool)
        case onboarding
    }

    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.analyticsClient) private var analyticsClient
    @Environment(\.appStartupReady) private var appStartupReady
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var presentsManageSubscriptions = false
    @State private var planSelection = SubscriptionPlanSelectionModel()
    @State private var onboardingActionFeedbackTrigger = 0

    let presentation: Presentation
    init(presentation: Presentation) {
        self.presentation = presentation
    }

    var body: some View {
        Group {
            switch presentation {
            case .standard:
                standardSubscriptionList
                    .navigationTitle("Subscription")
            case .onboarding:
                onboardingSubscriptionList
            }
        }
        .overlay {
            if subscription.operation != .idle {
                ProgressView(operationLabel)
                    .padding()
                    .background(
                        .regularMaterial,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .fieldBookElevation()
                    .accessibilityIdentifier("subscription-operation-progress")
            }
        }
        .manageSubscriptionsSheet(isPresented: $presentsManageSubscriptions)
        .task(id: appStartupReady) {
            if appStartupReady, subscription.planLoadState == .loading {
                await subscription.refresh()
            }
        }
        .onChange(of: displayedPlans, initial: true) { _, plans in
            reconcileSelectedPlan(with: plans)
        }
    }

    private var standardSubscriptionList: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: SubscriptionLayout.rowGap) {
                    VStack(alignment: .leading, spacing: SubscriptionLayout.subtitleGap) {
                        Text("FarrierFlow Pro")
                            .font(.headline)
                        Text(
                            "Run appointments, horse history, work, photos, invoices, and follow-up in one field-ready workflow."
                        )
                    }
                    Text("Your records stay on this iPhone. Cancel anytime; existing records remain available read only.")
                        .font(.footnote)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(ColorTokens.surface)

            if subscription.access == .pro {
                Section {
                    standardStatusRow(
                        Text("FarrierFlow Pro is active"),
                        systemImage: "checkmark.seal",
                        tint: ColorTokens.success
                    )
                    .accessibilityIdentifier("subscription-active-pro")
                }
                .listRowBackground(ColorTokens.surface)
            } else if subscription.access == .unavailable {
                Section {
                    standardAvailabilityMessage(
                        title: "Subscription Status Unavailable",
                        message: "FarrierFlow couldn’t verify your subscription. Try again."
                    )
                }
                .listRowBackground(ColorTokens.surface)
            } else if subscription.planLoadState == .loading {
                Section {
                    HStack(spacing: SubscriptionLayout.contentGap) {
                        ProgressView()
                            .controlSize(.small)
                            .frame(
                                width: SubscriptionLayout.symbolSide,
                                height: SubscriptionLayout.symbolSide
                            )
                            .accessibilityHidden(true)
                        Text("Loading Subscription Plans…")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("subscription-plans-loading")
                }
                .listRowBackground(ColorTokens.surface)
            } else if subscription.paywallIsAvailable {
                Section {
                    ForEach(subscription.plans) { plan in
                        Button {
                            Task {
                                await subscription.purchase(
                                    planID: plan.id,
                                    analyticsClient: analyticsClient
                                )
                            }
                        } label: {
                            SubscriptionPlanRow(plan: plan)
                        }
                        .buttonStyle(.plain)
                        .disabled(subscription.operation != .idle)
                        .accessibilityIdentifier(
                            "subscription-plan-\(plan.kind.accessibilityID)"
                        )
                    }
                } header: {
                    Text("Choose a Plan")
                } footer: {
                    Text("Any trial shown comes from the App Store. Each plan renews automatically unless canceled.")
                }
                .listRowBackground(ColorTokens.surface)
            } else {
                Section {
                    standardAvailabilityMessage(
                        title: "Plans Unavailable",
                        message: "Connect to the internet and try loading subscription plans again."
                    )
                }
                .listRowBackground(ColorTokens.surface)
            }

            if let errorMessage = subscription.errorMessage,
               subscription.access != .unavailable {
                Section {
                    standardStatusRow(
                        Text(errorMessage),
                        systemImage: "exclamationmark.circle",
                        tint: ColorTokens.textSecondary
                    )
                    .accessibilityIdentifier("subscription-error")
                }
                .listRowBackground(ColorTokens.surface)
            }

            Section {
                VStack(spacing: SubscriptionLayout.contentGap) {
                    Button {
                        Task {
                            await subscription.restorePurchases(
                                analyticsClient: analyticsClient
                            )
                        }
                    } label: {
                        standardBorderedActionLabel(
                            "Restore Purchases",
                            systemImage: "arrow.clockwise"
                        )
                    }
                    .farrierFlowBorderedAction()
                    .disabled(subscription.operation != .idle)
                    .accessibilityIdentifier("subscription-restore")

                    if showsManageSubscriptionButton {
                        Button {
                            presentsManageSubscriptions = true
                        } label: {
                            standardBorderedActionLabel(
                                "Manage Subscription",
                                systemImage: "creditcard"
                            )
                        }
                        .farrierFlowBorderedAction()
                        .accessibilityIdentifier("subscription-manage")
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(ColorTokens.surface)

            legalSection
        }
        .listSectionSpacing(.custom(SubscriptionLayout.sectionGap))
        .farrierFlowScrollBackground()
        .toolbarTitleDisplayMode(.inline)
        .toolbarVisibility(.hidden, for: .tabBar)
    }

    private func standardStatusRow(
        _ title: Text,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: SubscriptionLayout.contentGap) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(
                    width: SubscriptionLayout.symbolSide,
                    height: SubscriptionLayout.symbolSide
                )
                .accessibilityHidden(true)
            title
                .font(.headline)
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func standardAvailabilityMessage(
        title: LocalizedStringKey,
        message: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: SubscriptionLayout.contentGap) {
            HStack(alignment: .top, spacing: SubscriptionLayout.contentGap) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .frame(
                        width: SubscriptionLayout.symbolSide,
                        height: SubscriptionLayout.symbolSide
                    )
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SubscriptionLayout.subtitleGap) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)

            Button {
                Task { await subscription.refresh() }
            } label: {
                standardBorderedActionLabel(
                    "Retry",
                    systemImage: "arrow.clockwise"
                )
            }
            .farrierFlowBorderedAction()
            .accessibilityIdentifier("subscription-retry")
        }
        .padding(.vertical, 4)
    }

    private func standardBorderedActionLabel(
        _ title: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        HStack(spacing: SubscriptionLayout.rowGap) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(
                    width: SubscriptionLayout.symbolSide,
                    height: SubscriptionLayout.symbolSide
                )
                .accessibilityHidden(true)
            Text(title)
                .font(.body.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }

    private func standardLinkLabel(_ title: LocalizedStringKey) -> some View {
        HStack(spacing: SubscriptionLayout.rowGap) {
            Text(title)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: SubscriptionLayout.contentGap)
            Image(systemName: "arrow.up.right")
                .font(.title3.weight(.semibold))
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(
                    width: SubscriptionLayout.symbolSide,
                    height: SubscriptionLayout.symbolSide
                )
                .accessibilityHidden(true)
        }
        .foregroundStyle(ColorTokens.brandActionText)
        .padding(.horizontal, SubscriptionLayout.contentGap)
        .padding(.vertical, SubscriptionLayout.rowGap)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var onboardingSubscriptionList: some View {
        OnboardingPinnedTitleScrollView("FarrierFlow Pro") {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 6) {
                    OnboardingHeroTitle(title: "FarrierFlow Pro")

                    Text("Keep the work moving.")
                        .font(.title2.weight(.semibold))
                        .multilineTextAlignment(.center)

                    Text("Create and edit your business records.")
                        .foregroundStyle(ColorTokens.textSecondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier(
                            "subscription-onboarding-introduction"
                        )
                }
                .frame(maxWidth: .infinity, alignment: .center)

                onboardingPlanContent

                if let errorMessage = subscription.errorMessage,
                   subscription.access != .unavailable {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .accessibilityIdentifier("subscription-error")
                }

                if subscription.access != .pro, usesInlineOnboardingActions {
                    onboardingActionPanel
                        .padding(.top, 4)
                }

                VStack(spacing: 14) {
                    Button("Restore Purchases") {
                        Task {
                            await subscription.restorePurchases(
                                analyticsClient: analyticsClient
                            )
                        }
                    }
                    .disabled(subscription.operation != .idle)
                    .accessibilityIdentifier("subscription-restore")
                    .tint(ColorTokens.textSecondary)

                    HStack(spacing: 10) {
                        if let termsURL = URL(
                            string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
                        ) {
                            Link("Terms", destination: termsURL)
                        }
                        Text(verbatim: "·")
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                        if let privacyURL = URL(
                            string: "https://farrierflow.vercel.app/privacy/"
                        ) {
                            Link("Privacy", destination: privacyURL)
                        }
                    }
                    .font(.footnote)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .onboardingEntrance()
        }
        .safeAreaInset(edge: .bottom) {
            if subscription.access != .pro, !usesInlineOnboardingActions {
                onboardingActionPanel
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background {
                        ColorTokens.background
                            .allowsHitTesting(false)
                    }
            }
        }
        .tint(ColorTokens.brandActionText)
    }

    private var onboardingActionPanel: some View {
        VStack(spacing: 6) {
            if let selectedPlan {
                Button(action: performPrimaryOnboardingAction) {
                    Text(SubscriptionPurchaseCopy.actionTitle(for: selectedPlan))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("subscription-primary-purchase")
                .accessibilityHint(onboardingContinueAccessibilityHint)
                .farrierFlowPrimaryAction()
                .controlSize(.large)
                .disabled(subscription.operation != .idle)

                onboardingPurchaseDisclosure
                    .font(.caption)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier(
                        "subscription-purchase-explanation"
                    )
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(
            .impact(weight: .medium),
            trigger: onboardingActionFeedbackTrigger
        )
    }

    private var usesInlineOnboardingActions: Bool {
        dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact
    }

    private var onboardingContinueAccessibilityHint: Text {
        if let selectedPlan {
            if let trial = selectedPlan.introductoryTrial {
                return Text(
                    "Starts \(trial.localizedCallout), then subscribes for \(selectedPlan.localizedPrice) per \(selectedPlan.subscriptionPeriod)."
                )
            }
            return Text(
                "Subscribes for \(selectedPlan.localizedPrice) per \(selectedPlan.subscriptionPeriod)."
            )
        }
        return Text("Select a plan to subscribe.")
    }

    @ViewBuilder
    private var onboardingPlanContent: some View {
        if subscription.access == .pro {
            Label(
                "FarrierFlow Pro is active",
                systemImage: "checkmark.seal.fill"
            )
            .font(.headline)
            .foregroundStyle(ColorTokens.success)
            .accessibilityIdentifier("subscription-active-pro")
        } else if subscription.access == .unavailable {
            onboardingAvailabilityMessage(
                title: "Subscription Status Unavailable",
                message: "FarrierFlow couldn’t verify your subscription. Try again."
            )
        } else if subscription.planLoadState == .loading {
            ProgressView("Loading Subscription Plans…")
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .center)
                .accessibilityIdentifier("subscription-plans-loading")
        } else if subscription.paywallIsAvailable {
            VStack(alignment: .leading, spacing: 14) {
                OnboardingBillingSelector(
                    plans: displayedPlans,
                    selectedPlanID: planSelection.selectedPlanID,
                    savingsPercentage: annualSavingsPercentage,
                    isEnabled: subscription.operation == .idle,
                    onSelect: { plan in
                        planSelection.select(
                            plan,
                            analyticsClient: analyticsClient
                        )
                    }
                )

                if let selectedPlan {
                    OnboardingPlanDetailPanel(
                        plan: selectedPlan,
                        savingsPercentage: annualSavingsPercentage
                    )
                    .id(selectedPlan.id)
                    .transition(.opacity)
                }
            }
        } else {
            onboardingAvailabilityMessage(
                title: "Plans Unavailable",
                message: "Connect to the internet and try loading plans again."
            )
        }
    }

    private func onboardingAvailabilityMessage(
        title: LocalizedStringKey,
        message: LocalizedStringKey
    ) -> some View {
        VStack(spacing: 12) {
            Label(title, systemImage: "wifi.exclamationmark")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await subscription.refresh() }
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("subscription-retry")
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .center)
        .padding(SpacingTokens.standard)
        .background(
            ColorTokens.surfaceElevated,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .fieldBookElevation()
    }

    @ViewBuilder
    private var onboardingPurchaseDisclosure: some View {
        if let selectedPlan {
            Text(SubscriptionPurchaseCopy.disclosure(for: selectedPlan))
        }
    }

    private var annualSavingsPercentage: Int? {
        guard
            let monthly = displayedPlans.first(where: { $0.kind == .monthly }),
            let annual = displayedPlans.first(where: { $0.kind == .annual })
        else {
            return nil
        }
        return SubscriptionSavingsRules.annualSavingsPercentage(
            monthly: monthly,
            annual: annual
        )
    }

    private var legalSection: some View {
        Section {
            VStack(spacing: 0) {
                if let termsURL = URL(
                    string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
                ) {
                    Link(destination: termsURL) {
                        standardLinkLabel("Terms of Use")
                    }
                }
                if URL(
                    string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
                ) != nil,
                   URL(string: "https://farrierflow.vercel.app/privacy/") != nil {
                    Divider()
                        .padding(.horizontal, SubscriptionLayout.contentGap)
                }
                if let privacyURL = URL(
                    string: "https://farrierflow.vercel.app/privacy/"
                ) {
                    Link(destination: privacyURL) {
                        standardLinkLabel("Privacy Policy")
                    }
                }
            }
            .padding(.vertical, SubscriptionLayout.subtitleGap)
            .background(
                ColorTokens.surface,
                in: RoundedRectangle(cornerRadius: SubscriptionLayout.cardRadius, style: .continuous)
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } header: {
            Text("Legal")
        }
    }

    private var displayedPlans: [SubscriptionPlan] {
        guard presentation == .onboarding else {
            return subscription.plans
        }
        return subscription.plans.sorted {
            $0.kind.onboardingOrder < $1.kind.onboardingOrder
        }
    }

    private var selectedPlan: SubscriptionPlan? {
        displayedPlans.first { $0.id == planSelection.selectedPlanID }
    }

    private func reconcileSelectedPlan(with plans: [SubscriptionPlan]) {
        guard presentation == .onboarding else { return }
        planSelection.reconcile(with: plans)
    }

    private func continueFromOnboarding() {
        guard let planID = OnboardingSubscriptionDecisionRules.purchasePlanID(
            selectedPlanID: planSelection.selectedPlanID,
            availablePlans: displayedPlans
        ) else { return }
        Task {
            await subscription.purchase(
                planID: planID,
                analyticsClient: analyticsClient
            )
        }
    }

    private func performPrimaryOnboardingAction() {
        onboardingActionFeedbackTrigger += 1
        continueFromOnboarding()
    }


    private var showsManageSubscriptionButton: Bool {
        if case .standard(let showsManageSubscriptionButton) = presentation {
            return showsManageSubscriptionButton
        }
        return false
    }

    private var operationLabel: LocalizedStringKey {
        switch subscription.operation {
        case .idle: "Loading…"
        case .purchasing: "Completing Purchase…"
        case .restoring: "Restoring Purchases…"
        }
    }
}

private struct OnboardingBillingSelector: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let plans: [SubscriptionPlan]
    let selectedPlanID: String?
    let savingsPercentage: Int?
    let isEnabled: Bool
    let onSelect: (SubscriptionPlan) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(plans) { plan in
                Button {
                    withAnimation(
                        reduceMotion ? nil : .easeOut(duration: 0.2)
                    ) {
                        onSelect(plan)
                    }
                } label: {
                    selectorLabel(for: plan)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .foregroundStyle(
                    selectedPlanID == plan.id ? ColorTokens.brandActionText : ColorTokens.textPrimary
                )
                .background(
                    selectedPlanID == plan.id
                        ? ColorTokens.brandTint
                        : Color.clear,
                    in: Capsule(style: .continuous)
                )
                .disabled(!isEnabled)
                .accessibilityIdentifier(
                    "subscription-plan-\(plan.kind.accessibilityID)"
                )
                .accessibilityLabel(plan.kind == .annual ? "Yearly" : "Monthly")
                .accessibilityValue(accessibilityValue(for: plan))
                .accessibilityAddTraits(
                    selectedPlanID == plan.id ? .isSelected : []
                )
            }
        }
        .padding(3)
        .background(
            ColorTokens.surfaceElevated,
            in: Capsule(style: .continuous)
        )
        .fieldBookElevation()
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 320)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Billing period")
        .sensoryFeedback(.selection, trigger: selectedPlanID) { oldPlan, newPlan in
            oldPlan != nil && oldPlan != newPlan
        }
    }

    @ViewBuilder
    private func selectorLabel(for plan: SubscriptionPlan) -> some View {
        if plan.kind == .annual, let savingsPercentage {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Yearly")
                        .font(.headline)
                    savingsBadge(percentage: savingsPercentage)
                }

                VStack(spacing: 2) {
                    Text("Yearly")
                        .font(.headline)
                    savingsBadge(percentage: savingsPercentage)
                }
            }
        } else {
            Text("Monthly")
                .font(.headline)
        }
    }

    private func savingsBadge(percentage: Int) -> some View {
        Text("\(percentage)% off")
            .font(.caption2.weight(.bold))
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .foregroundStyle(ColorTokens.success)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                ColorTokens.successTint,
                in: Capsule(style: .continuous)
            )
    }

    private func accessibilityValue(for plan: SubscriptionPlan) -> Text {
        let price = String(
            localized: "\(plan.localizedPrice) per \(plan.subscriptionPeriod)"
        )
        let trial = plan.introductoryTrial.map {
            String(localized: $0.localizedCallout)
        }
        let savings = (plan.kind == .annual ? savingsPercentage : nil).map {
            String(localized: "Save \($0)% compared with monthly")
        }
        let monthlyEquivalent = (
            plan.kind == .annual ? plan.localizedMonthlyEquivalent : nil
        ).map {
            String(localized: "\($0) per month")
        }
        return Text(
            ([price] + [monthlyEquivalent, trial, savings].compactMap(\.self))
                .joined(separator: ", ")
        )
    }
}

private struct OnboardingPlanDetailPanel: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let plan: SubscriptionPlan
    let savingsPercentage: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 5) {
                        planTitle
                        planPrice
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        planTitle
                        Spacer(minLength: 8)
                        planPrice
                    }
                }
            }

            if let trial = plan.introductoryTrial {
                Label(trial.localizedCallout, systemImage: "gift.fill")
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                    .accessibilityIdentifier("subscription-trial-callout")
            }

            Divider()

            VStack(alignment: .leading, spacing: 2) {
                Text("Pro includes")
                    .font(.headline)

                OnboardingBenefitRow(
                    symbol: "calendar.badge.checkmark",
                    title: "The full job, from appointment to payment"
                )
                OnboardingBenefitRow(
                    symbol: "clock.arrow.circlepath",
                    title: "Complete horse and visit history"
                )
                OnboardingBenefitRow(
                    symbol: "doc.text.fill",
                    title: "Invoices from completed work"
                )
            }

            Divider()

            planDifference
        }
        .padding(18)
        .background(
            ColorTokens.surfaceElevated,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .fieldBookElevation()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("subscription-pro-benefits")
    }

    private var planTitle: some View {
        Text(plan.kind == .annual ? "Yearly Pro" : "Monthly Pro")
            .font(.title3.weight(.bold))
    }

    private var planPrice: some View {
        Text("\(plan.localizedPrice) / \(plan.subscriptionPeriod)")
            .font(.title3.weight(.semibold))
            .monospacedDigit()
    }

    @ViewBuilder
    private var planDifference: some View {
        if plan.kind == .annual {
            VStack(alignment: .leading, spacing: 4) {
                if let savingsPercentage {
                    Text("Save \(savingsPercentage)% compared with monthly")
                        .font(.headline)
                        .foregroundStyle(ColorTokens.textPrimary)
                }
                if let equivalent = plan.localizedMonthlyEquivalent {
                    Text("\(equivalent)/month, billed annually.")
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                } else {
                    Text("One payment covers 12 months of Pro.")
                        .font(.subheadline)
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Flexible monthly billing")
                    .font(.headline)
                Text("Full Pro access, billed one month at a time.")
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
    }
}

private struct OnboardingBenefitRow: View {
    let symbol: String
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: 26)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }
}

private struct SubscriptionPlanRow: View {
    let plan: SubscriptionPlan

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.kind == .annual ? "Annual" : "Monthly")
                    .font(.headline)
                    .foregroundStyle(ColorTokens.textPrimary)
                Text("Billed \(plan.localizedPrice) every \(plan.subscriptionPeriod)")
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                if let trial = plan.introductoryTrial {
                    Text(trial.localizedCallout)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            Spacer(minLength: 12)
            Text(plan.localizedPrice)
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(ColorTokens.textPrimary)
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

private extension SubscriptionPlanKind {
    var accessibilityID: String {
        switch self {
        case .monthly: "monthly"
        case .annual: "annual"
        }
    }

    var onboardingOrder: Int {
        switch self {
        case .monthly: 0
        case .annual: 1
        }
    }
}
