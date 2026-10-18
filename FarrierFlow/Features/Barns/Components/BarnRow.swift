import SwiftUI

struct BarnRow: View {
    let barn: Barn

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(barn.name)
                .font(Typography.recordTitle)
            Text(horseCountLabel)
                .font(Typography.recordMetadata)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("barn-row-\(barn.name)")
    }

    private var horseCountLabel: LocalizedStringKey {
        barn.horses.count == 1
            ? "1 horse"
            : "\(barn.horses.count) horses"
    }
}
