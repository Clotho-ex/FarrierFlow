import SwiftUI

struct BarnRow: View {
    let barn: Barn

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(barn.name)
                .font(Typography.recordTitle)
            if let address = barn.address {
                Text(address)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("barn-row-\(barn.name)")
    }
}
