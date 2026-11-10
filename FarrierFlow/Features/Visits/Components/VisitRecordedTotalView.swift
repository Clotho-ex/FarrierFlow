import SwiftUI

struct VisitRecordedTotalView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let total: VisitRecordedTotal
    var isDraft = false

    var body: some View {
        if total != .none {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    label
                } else if #available(iOS 26, *), !reduceTransparency {
                    label.glassEffect(.regular, in: .capsule)
                } else {
                    label.background(ColorTokens.surfaceElevated, in: .capsule)
                }
            }
            .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
            // Keep the capsule and transitioning text together as the footer changes height.
            .geometryGroup()
            .accessibilityLabel(isDraft ? Text("Draft visit total, \(amount)") : Text("Saved visit total, \(amount)"))
            .accessibilityHint("Recorded services across all clients in this visit.")
            .accessibilityIdentifier(isDraft ? "visit-draft-total" : "visit-saved-total")
        }
    }

    private var label: some View {
        Text(isDraft ? LocalizedStringKey("Draft total \(amount)") : LocalizedStringKey("Saved total \(amount)"))
            .rollingStateText(value: "\(isDraft)-\(amount)")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ColorTokens.textPrimary)
            .monospacedDigit()
            .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 0 : SpacingTokens.standard)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 0 : SpacingTokens.compact)
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
