import SwiftUI

struct VisitRecordedTotalView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.locale) private var locale
    let total: VisitRecordedTotal

    var body: some View {
        if total != .none {
            Group {
                if #available(iOS 26, *), !reduceTransparency {
                    label.glassEffect(.regular, in: .capsule)
                } else {
                    label.background(ColorTokens.surfaceElevated, in: .capsule)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Saved visit total, \(amount)")
            .accessibilityHint("Recorded services across all clients in this visit.")
            .accessibilityIdentifier("visit-saved-total")
        }
    }

    private var label: some View {
        Text("Saved total \(amount)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ColorTokens.textPrimary)
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.standard)
            .padding(.vertical, SpacingTokens.compact)
    }

    private var amount: String {
        switch total {
        case .none, .unavailable:
            String(localized: "Unavailable", locale: locale)
        case let .available(minorUnits, currencyCode):
            MoneyFormatter.currency(minorUnits: minorUnits, currencyCode: currencyCode, locale: locale)
                ?? String(localized: "Unavailable", locale: locale)
        }
    }
}
