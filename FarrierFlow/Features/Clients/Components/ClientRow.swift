import SwiftUI

struct ClientRow: View {
    let client: Client

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(client.name)
                .font(Typography.recordTitle)
            if let phone = client.phone {
                Text(phone)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("client-row-\(client.name)")
    }
}
