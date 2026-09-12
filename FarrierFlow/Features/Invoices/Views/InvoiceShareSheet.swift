import SwiftUI
import UIKit

struct InvoiceShareSheet: UIViewControllerRepresentable {
    let url: URL
    let completion: (Bool) -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, completed, _, _ in
            completion(completed)
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}

@MainActor
enum InvoiceShareCompletion {
    static func handle(
        didComplete: Bool,
        analyticsClient: any AnalyticsClient,
        cleanup: () -> Void
    ) {
        if didComplete {
            analyticsClient.track(.invoiceShared)
        }
        cleanup()
    }
}
