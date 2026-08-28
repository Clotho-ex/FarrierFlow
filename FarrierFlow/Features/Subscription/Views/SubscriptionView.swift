import StoreKit
import SwiftUI

struct SubscriptionView: View {
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var presentsManageSubscriptions = false

    let showsManageSubscriptionButton: Bool

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("FarrierFlow Pro")
                        .font(.title2.bold())
                    Text("Run appointments, horse history, work, photos, invoices, and follow-up in one field-ready workflow.")
                    Text("Your records stay on this iPhone. Cancel anytime; existing records remain available read only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if subscription.access == .pro {
                Section {
                    Label("FarrierFlow Pro is active", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .accessibilityIdentifier("subscription-active-pro")
                }
            } else if subscription.paywallIsAvailable {
                Section {
                    ForEach(subscription.plans) { plan in
                        Button {
                            Task { await subscription.purchase(planID: plan.id) }
                        } label: {
                            SubscriptionPlanRow(plan: plan)
                        }
                        .disabled(subscription.operation != .idle)
                        .accessibilityIdentifier("subscription-plan-\(plan.kind.accessibilityID)")
                    }
                } header: {
                    Text("Choose a Plan")
                } footer: {
                    Text("14-day free trial for eligible new subscribers. Each plan renews automatically unless canceled.")
                }
            } else {
                Section {
                    ContentUnavailableView {
                        Label("Plans Unavailable", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text("Connect to the internet and try loading subscription plans again.")
                    } actions: {
                        Button("Retry") { Task { await subscription.refresh() } }
                            .accessibilityIdentifier("subscription-retry")
                    }
                }
            }

            if let errorMessage = subscription.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("subscription-error")
                }
            }

            Section {
                Button("Restore Purchases") {
                    Task { await subscription.restorePurchases() }
                }
                .disabled(subscription.operation != .idle)
                .accessibilityIdentifier("subscription-restore")

                if showsManageSubscriptionButton {
                    Button("Manage Subscription") {
                        presentsManageSubscriptions = true
                    }
                    .accessibilityIdentifier("subscription-manage")
                }
            }

            Section("Legal") {
                if let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                    Link("Terms of Use", destination: termsURL)
                }
                if let privacyURL = URL(string: "https://farrierflow.vercel.app/privacy/") {
                    Link("Privacy Policy", destination: privacyURL)
                }
            }
        }
        .navigationTitle("Subscription")
        .overlay {
            if subscription.operation != .idle {
                ProgressView(operationLabel)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("subscription-operation-progress")
            }
        }
        .manageSubscriptionsSheet(isPresented: $presentsManageSubscriptions)
        .task {
            if subscription.plans.isEmpty { await subscription.refresh() }
        }
    }

    private var operationLabel: LocalizedStringKey {
        switch subscription.operation {
        case .idle: "Loading…"
        case .purchasing: "Completing Purchase…"
        case .restoring: "Restoring Purchases…"
        }
    }
}

private struct SubscriptionPlanRow: View {
    let plan: SubscriptionPlan

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.kind == .annual ? "Annual" : "Monthly")
                    .font(.headline)
                Text("Billed \(plan.localizedPrice) every \(plan.subscriptionPeriod)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text(plan.localizedPrice)
                .font(.headline)
                .monospacedDigit()
        }
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
}
