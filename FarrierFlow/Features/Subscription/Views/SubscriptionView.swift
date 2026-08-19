import StoreKit
import SwiftUI

struct SubscriptionView: View {
    let showsManageSubscriptionButton: Bool

    @State private var presentsManageSubscriptions = false

    var body: some View {
        SubscriptionStoreView(productIDs: SubscriptionProduct.orderedIdentifiers) {
            VStack(alignment: .leading, spacing: 12) {
                Text("FarrierFlow Pro")
                    .font(.title2.bold())
                Text(
                    "Run appointments, horse history, work, photos, invoices, and follow-up in one field-ready workflow."
                )
                Text(
                    "Your records stay on this iPhone. Cancel anytime; existing records remain available read only."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .subscriptionStoreControlStyle(.picker)
        .storeButton(.visible, for: .restorePurchases)
        .navigationTitle("Subscription")
        .toolbar {
            if showsManageSubscriptionButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Manage Subscription") {
                        presentsManageSubscriptions = true
                    }
                }
            }
        }
        .manageSubscriptionsSheet(isPresented: $presentsManageSubscriptions)
    }
}
