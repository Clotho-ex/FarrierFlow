import SwiftUI

struct SubscriptionWelcomeView: View {
    var body: some View {
        NavigationStack {
            SubscriptionView(showsManageSubscriptionButton: false)
                .accessibilityIdentifier("subscription-welcome")
        }
    }
}
