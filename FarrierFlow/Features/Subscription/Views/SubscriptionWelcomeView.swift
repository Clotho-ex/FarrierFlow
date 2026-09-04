import SwiftUI

struct SubscriptionWelcomeView: View {
    var body: some View {
        NavigationStack {
            SubscriptionView(
                presentation: .standard(
                    showsManageSubscriptionButton: false
                )
            )
                .accessibilityIdentifier("subscription-welcome")
        }
    }
}
