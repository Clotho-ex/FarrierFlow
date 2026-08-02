import SwiftData
import SwiftUI

struct OwnerSetupView: View {
    @Environment(\.modelContext) private var context

    let model: OwnerSetupReadinessModel
    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch model.loadState {
                case .loading:
                    ProgressView("Loading Setup…")
                case .failed:
                    unavailableContent
                case .loaded:
                    BusinessProfileEditorView(mode: .identity) {
                        model.load(in: context)
                        if model.hasValidIdentity {
                            onFinish()
                        }
                    }
                }
            }
            .onAppear {
                if model.loadState == .loading {
                    model.load(in: context)
                }
            }
        }
    }

    private var unavailableContent: some View {
        ContentUnavailableView {
            Label("Setup Unavailable", systemImage: "exclamationmark.circle")
        } description: {
            Text("FarrierFlow couldn’t load your setup. Try again.")
        } actions: {
            Button("Retry") {
                model.load(in: context)
            }
        }
    }
}
