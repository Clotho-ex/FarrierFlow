import SwiftUI

struct ClientRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let client: ClientListSnapshot

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                stackedContent
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 0) {
                        clientInformation
                            .fixedSize(horizontal: true, vertical: false)
                        Spacer(minLength: SpacingTokens.related)
                        horseCount
                            .fixedSize()
                    }
                    stackedContent
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("client-row-\(client.name)")
    }

    private var clientInformation: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(client.name)
                .font(Typography.recordTitle)
                .fixedSize(horizontal: false, vertical: true)
            if let phone = client.phone {
                Text(phone)
                    .font(Typography.recordMetadata)
                    .foregroundStyle(ColorTokens.textSecondary)
            }
        }
    }

    private var stackedContent: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            clientInformation
            horseCount
        }
    }

    private var horseCount: some View {
        Text("\(client.horseCount) horses")
            .font(Typography.recordMetadata)
            .foregroundStyle(ColorTokens.textSecondary)
    }
}
