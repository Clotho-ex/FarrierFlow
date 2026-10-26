import SwiftUI

struct VisitHorseExecutionHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let horse: VisitHorseDraft
    let information: VisitHorseContext?
    let showsClient: Bool
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            DisclosureGroup(isExpanded: $isExpanded) {
                EmptyView()
            } label: {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: SpacingTokens.compact) {
                        nameAndSafety
                        status
                    }
                } else {
                    HStack(alignment: .center, spacing: SpacingTokens.compact) {
                        nameAndSafety
                        Spacer(minLength: SpacingTokens.compact)
                        status
                    }
                }
            }
            .tint(ColorTokens.textSecondary)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityIdentifier("visit-horse-toggle-\(horse.horseName)")
            if showsClient, let client = information?.clientName {
                Text("Client · \(client)")
                    .font(Typography.recordMetadata)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
            if !isExpanded, horse.hasRecordedOutcome, horse.outcome == .serviced {
                Text(horse.workItems.map(\.serviceNameSnapshot).joined(separator: " · "))
                    .font(.footnote)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            }
        }
    }

    @ViewBuilder
    private var nameAndSafety: some View {
        if let notes = information?.safetyNotes {
            Text("\(Text(verbatim: horse.horseName).font(Typography.recordTitle).foregroundStyle(ColorTokens.textPrimary)) \(Image(systemName: "exclamationmark.triangle")) \(Text(verbatim: notes))")
                .font(.subheadline)
                .foregroundStyle(ColorTokens.warning)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            name
        }
    }

    private var name: some View {
        Text(verbatim: horse.horseName)
            .font(Typography.recordTitle)
            .foregroundStyle(ColorTokens.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var statusTitle: LocalizedStringResource {
        horse.outcome == .serviced && !horse.hasRecordedOutcome ? "Needs Service" : horse.outcome.localizedTitle
    }

    private var status: some View {
        Text(statusTitle)
            .font(.subheadline)
            .foregroundStyle(horse.hasRecordedOutcome && horse.outcome == .serviced
                             ? ColorTokens.success : ColorTokens.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var accessibilityLabel: String {
        var parts = [horse.horseName, String(localized: statusTitle)]
        if let client = information?.clientName {
            parts.append(String(localized: "Client, \(client)"))
        }
        if let notes = information?.safetyNotes {
            parts.append(String(localized: "Safety Notes, \(notes)"))
        }
        return parts.joined(separator: ", ")
    }
}
