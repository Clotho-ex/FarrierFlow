import SwiftUI

enum HorseRowContext {
    case collection
    case clientDetail
    case serviceLocationDetail
}

struct HorseRow: View {
    let horse: HorseDetailSnapshot
    let context: HorseRowContext

    init(
        horse: Horse,
        context: HorseRowContext = .collection
    ) {
        self.init(horse: HorseDetailSnapshot(horse: horse), context: context)
    }

    init(horse: HorseDetailSnapshot, context: HorseRowContext = .collection) {
        self.horse = horse
        self.context = context
    }

    private var clientName: String {
        horse.client?.name ?? String(localized: "Client unavailable")
    }

    private var barnName: String {
        horse.currentBarn?.name ?? String(localized: "Service location unavailable")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(horse.name)
                .font(Typography.recordTitle)
            Text(metadata)
                .font(Typography.recordMetadata)
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("horse-row-\(horse.name)")
    }

    private var metadata: String {
        switch context {
        case .collection:
            "\(clientName) · \(barnName)"
        case .clientDetail:
            barnName
        case .serviceLocationDetail:
            clientName
        }
    }
}
