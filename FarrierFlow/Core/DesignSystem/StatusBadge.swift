import SwiftUI

enum StatusTone {
    case neutral
    case active
    case success
    case warning
    case destructive
    case information

    var emphasis: Color {
        switch self {
        case .neutral:
            ColorTokens.textSecondary
        case .active:
            ColorTokens.brandPrimary
        case .success:
            ColorTokens.success
        case .warning:
            ColorTokens.warning
        case .destructive:
            ColorTokens.destructive
        case .information:
            ColorTokens.information
        }
    }

    var background: Color {
        switch self {
        case .neutral:
            ColorTokens.surfaceElevated
        case .active:
            ColorTokens.brandTint
        case .success:
            ColorTokens.successTint
        case .warning:
            ColorTokens.warningTint
        case .destructive:
            ColorTokens.destructiveTint
        case .information:
            ColorTokens.information.opacity(0.14)
        }
    }

    var systemImage: String {
        switch self {
        case .neutral:
            "circle"
        case .active:
            "circle.lefthalf.filled"
        case .success:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        case .destructive:
            "xmark.octagon.fill"
        case .information:
            "info.circle.fill"
        }
    }
}

struct StatusBadge: View {
    let title: String
    let tone: StatusTone

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Image(systemName: tone.systemImage)
                .foregroundStyle(tone.emphasis)
                .fixedSize()
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(ColorTokens.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption.weight(.semibold))
        .multilineTextAlignment(.leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tone.background, in: RoundedRectangle(cornerRadius: SpacingTokens.related))
        .overlay {
            RoundedRectangle(cornerRadius: SpacingTokens.related)
                .stroke(ColorTokens.border.opacity(0.55), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}
