import SwiftUI
import UIKit

struct InvoiceShareSheet: UIViewControllerRepresentable {
    let url: URL
    let completion: () -> Void
    func makeUIViewController(context: Context) -> UIActivityViewController { let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil); controller.completionWithItemsHandler = { _, _, _, _ in completion() }; return controller }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
