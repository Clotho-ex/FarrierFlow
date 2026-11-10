import SwiftData
import SwiftUI

struct VisitHorseNotesRow: View {
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var isExpanded = false
    @Binding var note: String
    @FocusState.Binding var focusedHorseID: PersistentIdentifier?
    let horseID: PersistentIdentifier
    let horseName: String
    var isNotServiced = false

    private var title: LocalizedStringKey { isNotServiced ? "Reason" : "Work Notes" }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.compact) {
            DisclosureGroup(isExpanded: $isExpanded) {
                EmptyView()
            } label: {
                if !isExpanded, TextNormalization.optional(note) == nil {
                    LabeledContent(title) {
                        Text("Add Note").foregroundStyle(ColorTokens.textSecondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
                        Text(title)
                        if !isExpanded {
                            Text(verbatim: note)
                                .lineLimit(2)
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                }
            }
            .tint(ColorTokens.textSecondary)
            .accessibilityIdentifier("visit-work-notes-toggle-\(horseName)")
            if isExpanded {
                if subscription.allowsMutations {
                    TextField(title, text: $note, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focusedHorseID, equals: horseID)
                        .accessibilityLabel(Text(title))
                        .accessibilityIdentifier("visit-work-notes-\(horseName)")
                        .inputLimit($note, maximum: InputLimits.notes)
                } else {
                    Text(verbatim: note)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .focusedInputAnchor(horseID)
        .onChange(of: isExpanded) { _, expanded in
            focusedHorseID = expanded && subscription.allowsMutations ? horseID : nil
        }
    }
}
