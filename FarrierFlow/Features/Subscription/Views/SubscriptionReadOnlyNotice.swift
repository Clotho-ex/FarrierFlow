import SwiftUI

struct SubscriptionReadOnlyNotice: View {
    let access: SubscriptionAccess
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: icon)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("subscription-read-only-notice")
        .accessibilityHint("Opens Subscription")
    }

    private var title: LocalizedStringKey {
        access == .unavailable
            ? "Subscription Status Unavailable"
            : "Subscription Required"
    }

    private var icon: String {
        access == .unavailable ? "wifi.exclamationmark" : "lock"
    }

    private var message: LocalizedStringKey {
        access == .unavailable
            ? "Your existing records remain available read only. Try again from Subscription."
            : "Your existing records remain available. Subscribe to make changes."
    }
}
