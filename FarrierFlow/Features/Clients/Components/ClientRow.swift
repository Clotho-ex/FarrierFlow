import SwiftUI

struct ClientRow: View {
    @Environment(\.openURL) private var openURL
    let client: ClientListSnapshot

    var body: some View {
        HStack(spacing: SpacingTokens.related) {
            RecordNavigationLink(value: ClientRoute.detail(client.id)) {
                VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                    Text(client.name)
                        .font(Typography.recordTitle)
                    horseCount
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("client-row-\(client.name)")

            if let phone = client.phone, let url = ClientContactURL.phone(phone) {
                Button {
                    openURL(url)
                } label: {
                    Image(systemName: "phone")
                        .font(.body)
                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(width: SpacingTokens.minimumTouchTarget, height: SpacingTokens.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Call \(client.name)"))
                .accessibilityIdentifier("client-call-\(client.name)")
            }
        }
    }

    private var horseCount: some View {
        Group {
            if client.horseCount == 1 {
                Text("1 horse")
            } else {
                Text("\(client.horseCount) horses")
            }
        }
        .font(Typography.recordMetadata)
        .foregroundStyle(ColorTokens.textSecondary)
    }
}
