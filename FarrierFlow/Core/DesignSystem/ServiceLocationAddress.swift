import Foundation
import SwiftUI

struct ServiceLocationAddress: View {
    let address: String
    var title: LocalizedStringKey? = nil

    var body: some View {
        if let url = ServiceLocationDirections.url(for: address) {
            Link(destination: url) {
                ExternalLinkLabel { addressLabel }
                    .frame(
                        minWidth: SpacingTokens.minimumTouchTarget,
                        minHeight: SpacingTokens.minimumTouchTarget,
                        alignment: .leading
                    )
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Directions to \(address)"))
            .accessibilityIdentifier("service-location-directions")
        } else {
            addressLabel
        }
    }

    @ViewBuilder
    private var addressLabel: some View {
        if let title {
            RecordDetailField(title) {
                addressText
            }
        } else {
            addressText
        }
    }

    private var addressText: some View {
        Text(verbatim: address)
            .fixedSize(horizontal: false, vertical: true)
    }
}

nonisolated enum ServiceLocationDirections {
    static func url(for address: String) -> URL? {
        let destination = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.queryItems = [URLQueryItem(name: "daddr", value: destination)]
        return components.url
    }
}
