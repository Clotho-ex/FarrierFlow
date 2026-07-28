import SwiftUI
import UIKit

struct CameraCaptureView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (Data) -> Void
    let onFailure: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(
        _: UIImagePickerController,
        context _: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate {
        private let parent: CameraCaptureView

        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(
            _: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let sourceURL = info[.imageURL] as? URL else {
                parent.onFailure()
                parent.dismiss()
                return
            }
            Task {
                do {
                    let data = try await Task.detached(priority: .userInitiated) {
                        try Data(contentsOf: sourceURL, options: .mappedIfSafe)
                    }.value
                    parent.onCapture(data)
                } catch {
                    parent.onFailure()
                }
                parent.dismiss()
            }
        }
    }
}
