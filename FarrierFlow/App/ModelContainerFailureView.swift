import SwiftUI

struct ModelContainerFailureView: View {
    var body: some View {
        ContentUnavailableView(
            "Couldn’t Open FarrierFlow",
            systemImage: "exclamationmark.triangle",
            description: Text(
                "FarrierFlow couldn’t open its local records. Close the app and try again."
            )
        )
    }
}
