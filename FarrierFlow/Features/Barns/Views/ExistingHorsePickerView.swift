import SwiftData
import SwiftUI

struct ExistingHorsePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model = ExistingHorsePickerModel()

    let destinationBarnID: PersistentIdentifier

    var body: some View {
        NavigationStack {
            List(selection: $model.selectedHorseID) {
                ForEach(model.horses, id: \.id) { horse in
                    HorseRow(horse: horse)
                        .tag(horse.id)
                        .listRowBackground(ColorTokens.surface)
                }
            }
            .farrierFlowScrollBackground()
            .overlay {
                if model.loadState == .loading {
                    ProgressView("Loading horses…")
                } else if model.loadState == .failed {
                    ContentUnavailableView {
                        Label("Horses Unavailable", systemImage: "exclamationmark.circle")
                    } description: {
                        Text("FarrierFlow couldn’t load horses for this service location.")
                    } actions: {
                        Button("Retry") {
                            model.load(
                                destinationBarnID: destinationBarnID,
                                in: ModelContext(context.container)
                            )
                        }
                    }
                } else if model.horses.isEmpty {
                    ContentUnavailableView(
                        "No eligible horses",
                        systemImage: "figure.equestrian.sports",
                        description: Text(
                            "Only horses with no unresolved or in-progress appointments can move."
                        )
                    )
                }
            }
            .navigationTitle("Add Existing Horse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(ColorTokens.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if subscription.allowsMutations {
                    Button("Move") {
                        move()
                    }
                    .disabled(
                        model.loadState != .loaded
                            || model.selectedHorseID == nil
                    )
                    }
                }
            }
            .onAppear {
                model.load(destinationBarnID: destinationBarnID, in: ModelContext(context.container))
            }
            .alert(item: $model.alert) {
                if let relocation = model.pendingRelocation {
                    Alert(
                        title: Text($0.title), message: Text($0.message),
                        primaryButton: .default(Text("Move Horse")) { move(confirming: relocation) },
                        secondaryButton: .cancel()
                    )
                } else {
                    Alert(title: Text($0.title), message: Text($0.message))
                }
            }
        }
    }
    private func move(confirming relocation: HorseRelocationConfirmation? = nil) {
        guard subscription.allowsMutations else { return }
        if model.move(to: destinationBarnID, in: ModelContext(context.container), confirming: relocation) {
            dismiss()
        }
    }

}
