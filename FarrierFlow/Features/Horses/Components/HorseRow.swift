import SwiftUI

struct HorseRow: View {
    let horse: Horse

    private var clientName: String {
        horse.client?.name ?? String(localized: "Client unavailable")
    }

    private var barnName: String {
        horse.currentBarn?.name ?? String(localized: "Service location unavailable")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(horse.name)
                .font(Typography.recordTitle)
            Text("\(clientName) · \(barnName)")
                .font(Typography.recordMetadata)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("horse-row-\(horse.name)")
    }
}
