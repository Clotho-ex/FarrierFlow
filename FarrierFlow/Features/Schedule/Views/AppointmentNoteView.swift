import SwiftUI

struct AppointmentNoteView: View {
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.compact) {
            Text("Notes")
                .font(.footnote)
                .foregroundStyle(ColorTokens.textSecondary)
            Text(note)
                .font(.body)
                .foregroundStyle(ColorTokens.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(SpacingTokens.related)
                .background(
                    ColorTokens.noteSurface,
                    in: .rect(cornerRadius: SpacingTokens.related)
                )
                .textSelection(.enabled)
        }
    }
}
