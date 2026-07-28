import SwiftData
import SwiftUI

struct PhotographCountLabel: View {
    let visitHorseID: PersistentIdentifier
    let library: PhotographLibrary
    @State private var count = 0

    var body: some View {
        LabeledContent("Hoof Photographs", value: "\(count)")
            .onAppear {
                count = (try? library.items(for: visitHorseID).count) ?? 0
            }
            .accessibilityValue("\(count) photographs")
    }
}
