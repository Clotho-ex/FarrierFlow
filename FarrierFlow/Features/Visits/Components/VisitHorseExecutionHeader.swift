import SwiftUI

struct VisitHorseExecutionHeader: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let horse: VisitHorseDraft
    let information: VisitHorseContext?
    let showsClient: Bool
    @Binding var isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.compact) {
            // Keep the header independent of the expanding Form rows.
            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: SpacingTokens.compact) {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: SpacingTokens.compact) {
                            name
                            status
                        }
                        Spacer(minLength: SpacingTokens.compact)
                    } else {
                        name
                        Spacer(minLength: SpacingTokens.compact)
                        status
                    }
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(width: 14, height: 14)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, minHeight: SpacingTokens.minimumTouchTarget, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(isExpanded ? Text("Expanded") : Text("Collapsed"))
            .accessibilityIdentifier("visit-horse-toggle-\(horse.horseName)")
            if let notes = information?.safetyNotes {
                HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.compact) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(ColorTokens.warning)
                        .accessibilityHidden(true)
                    Text(verbatim: notes)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.bottom, showsClient ? SpacingTokens.compact : 0)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Safety note for \(horse.horseName): \(notes)")
                .accessibilityIdentifier("visit-safety-notes-\(horse.horseName)")
            }
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

    private var name: some View {
        Text(verbatim: horse.horseName)
            .accessibilityIdentifier("visit-horse-name-\(horse.horseName)")
            .font(Typography.recordTitle)
            .foregroundStyle(ColorTokens.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var statusTitle: LocalizedStringResource {
        if horse.outcome == .pending { return "In Progress" }
        return horse.outcome == .serviced && !horse.hasRecordedOutcome ? "Needs Service" : horse.outcome.localizedTitle
    }

    private var status: some View {
        Text(statusTitle)
            .accessibilityIdentifier("visit-horse-status-\(horse.horseName)")
            .font(.subheadline)
            .foregroundStyle(horse.hasRecordedOutcome && horse.outcome == .serviced
                             ? ColorTokens.success : ColorTokens.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .rollingStateText(value: String(localized: statusTitle))
    }

    private var accessibilityLabel: String {
        var parts = [horse.horseName, String(localized: statusTitle)]
        if let client = information?.clientName {
            parts.append(String(localized: "Client, \(client)"))
        }
        return parts.joined(separator: ", ")
    }
}
