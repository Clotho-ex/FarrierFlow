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
                ForEach(model.horses, id: \.persistentModelID) { horse in
                    HorseRow(horse: horse)
                        .tag(horse.persistentModelID)
                }
            }
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
                                in: context
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
                }
                ToolbarItem(placement: .confirmationAction) {
                    if subscription.allowsMutations {
                    Button("Move") {
                        guard subscription.allowsMutations else { return }
                        if model.move(to: destinationBarnID, in: context) {
                            dismiss()
                        }
                    }
                    .disabled(
                        model.loadState != .loaded
                            || model.selectedHorseID == nil
                    )
                    }
                }
            }
            .onAppear {
                model.load(destinationBarnID: destinationBarnID, in: context)
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
    }
}
