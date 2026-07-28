import SwiftData
import SwiftUI
import UIKit

struct PhotographCountLabel: View {
    @State private var model: PhotographCountModel

    init(visitHorseID: PersistentIdentifier, library: PhotographLibrary) {
        _model = State(
            initialValue: PhotographCountModel(
                visitHorseID: visitHorseID,
                library: library
            )
        )
    }

    var body: some View {
        LabeledContent("Hoof Photographs") {
            switch model.state {
            case .loading:
                ProgressView()
                    .accessibilityLabel("Loading Photographs…")
            case .loaded(let count):
                Text("\(count)")
            case .unavailable:
                Text("Unavailable")
            }
        }
        .task {
            model.load()
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: UIApplication.protectedDataDidBecomeAvailableNotification
            )
        ) { _ in
            model.load()
        }
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        switch model.state {
        case .loading:
            "Loading photographs"
        case .loaded(let count):
            "\(count) photographs"
        case .unavailable:
            "Photographs unavailable"
        }
    }
}
