import SwiftUI

struct SubscriptionReadOnlyNotice: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Subscription Required", systemImage: "lock")
                    .font(.headline)
                Text("Your existing records remain available. Subscribe to make changes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("subscription-read-only-notice")
        .accessibilityHint("Opens Subscription")
    }
}
