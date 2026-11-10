import SwiftData
import SwiftUI
import UIKit

struct VisitPhotographsRow: View {
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.backupSync) private var backupSync
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: PhotographCountModel
    let horse: VisitHorseDraft
    let library: PhotographLibrary

    init(horse: VisitHorseDraft, library: PhotographLibrary) {
        self.horse = horse
        self.library = library
        _model = State(initialValue: PhotographCountModel(visitHorseID: horse.id, library: library))
    }

    var body: some View {
        Group {
            if isEmpty {
                RecordNavigationLink { destination } label: { photoLabel }
            } else {
                NavigationLink { destination } label: { photoLabel }
            }
        }
        .accessibilityHint("View or add photos for this horse")
        .accessibilityIdentifier("visit-photographs-\(horse.horseName)")
        .task { model.load() }
        .onChange(of: backupSync?.runtime?.photographsVersion) { _, _ in model.load() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.protectedDataDidBecomeAvailableNotification)) { _ in
            model.load()
        }
    }

    private var destination: some View {
        PhotographCollectionView(visitHorseID: horse.id, horseName: horse.horseName, library: library)
    }

    private var photoLabel: some View {
        layout {
            Label {
                Text(isEmpty ? "Add Photo" : "Photos")
                .rollingStateText(value: isEmpty)
            } icon: {
                Image(systemName: isEmpty ? "plus" : "photo.on.rectangle")
            }
            .accessibilityIdentifier("visit-photographs-label-\(horse.horseName)")
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: SpacingTokens.compact) }
            switch model.state {
            case .loading:
                ProgressView()
            case .loaded(let count) where count > 0:
                Text(count, format: .number)
                    .rollingStateText(value: count)
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
                    .accessibilityLabel("\(count) photos")
            case .unavailable:
                Text("Unavailable")
                    .font(.subheadline)
                    .foregroundStyle(ColorTokens.textSecondary)
            case .loaded:
                EmptyView()
            }
        }
    }

    private var isEmpty: Bool {
        model.state == .loaded(0) && subscription.allowsMutations
    }

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SpacingTokens.compact))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: SpacingTokens.compact))
    }
}
