import SwiftUI

struct ClientRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL
    let client: ClientListSnapshot

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SpacingTokens.related))
            : AnyLayout(HStackLayout(spacing: SpacingTokens.related))
        layout {
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

            HStack(spacing: SpacingTokens.compact) {
                if let phone = client.phone, let url = ClientContactURL.phone(phone) {
                    contactButton(
                        url: url, systemImage: "phone.fill",
                        foreground: ColorTokens.success, background: ColorTokens.successTint
                    )
                        .accessibilityLabel(Text("Call \(client.name)"))
                        .accessibilityIdentifier("client-call-\(client.name)")
                }
                if let email = client.email, let url = ClientContactURL.email(email) {
                    contactButton(
                        url: url, systemImage: "envelope.fill",
                        foreground: ColorTokens.textPrimary, background: ColorTokens.noteSurface
                    )
                        .accessibilityLabel(Text("Email \(client.name)"))
                        .accessibilityIdentifier("client-email-\(client.name)")
                }
            }
        }
    }

    private func contactButton(
        url: URL, systemImage: String, foreground: Color, background: Color
    ) -> some View {
        Button { openURL(url) } label: {
            Image(systemName: systemImage)
                .font(.body)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(foreground)
                .frame(width: SpacingTokens.minimumTouchTarget, height: SpacingTokens.minimumTouchTarget)
                .background(background, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
    }

    private var horseCount: some View {
        Text("\(client.horseCount) horses")
            .rollingStateText(value: client.horseCount)
            .font(Typography.recordMetadata)
            .foregroundStyle(ColorTokens.textSecondary)
    }
}
