import SwiftData
import SwiftUI

struct ExistingHorsePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
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
                if model.horses.isEmpty {
                    ContentUnavailableView(
                        "No eligible horses",
                        systemImage: "figure.equestrian.sports",
                        description: Text(
                            "Only horses without appointments at another service location can move."
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
                    Button("Move") {
                        if model.move(to: destinationBarnID, in: context) {
                            dismiss()
                        }
                    }
                    .disabled(model.selectedHorseID == nil)
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
