import Foundation
import ImageIO
import UIKit

nonisolated enum CameraCaptureResultAdapter {
    static func sourceData(
        from info: [UIImagePickerController.InfoKey: Any]
    ) async throws -> Data {
        let imageURL = info[.imageURL] as? URL
        let originalImage = info[.originalImage] as? UIImage
        return try await Task.detached(priority: .userInitiated) {
            if let imageURL,
               let data = try? Data(contentsOf: imageURL, options: .mappedIfSafe),
               isDecodableImageData(data) {
                return data
            }

            if let originalImage,
               let data = uprightJPEGData(from: originalImage),
               isDecodableImageData(data) {
                return data
            }

            throw CameraCaptureResultError.unreadableCapture
        }.value
    }

    private static func uprightJPEGData(from image: UIImage) -> Data? {
        guard let cgImage = image.cgImage,
              cgImage.width > 0,
              cgImage.height > 0 else {
            return nil
        }

        let visiblePixelSize = visiblePixelSize(for: image, cgImage: cgImage)
        let longestEdge = max(visiblePixelSize.width, visiblePixelSize.height)
        let scale = min(1, CGFloat(PhotographConstants.maximumLongestEdge) / longestEdge)
        let outputSize = CGSize(
            width: max(1, (visiblePixelSize.width * scale).rounded(.down)),
            height: max(1, (visiblePixelSize.height * scale).rounded(.down))
        )
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.jpegData(withCompressionQuality: 1) { _ in
            image.draw(in: CGRect(origin: .zero, size: outputSize))
        }
    }

    private static func visiblePixelSize(for image: UIImage, cgImage: CGImage) -> CGSize {
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            CGSize(width: cgImage.height, height: cgImage.width)
        case .up, .upMirrored, .down, .downMirrored:
            CGSize(width: cgImage.width, height: cgImage.height)
        @unknown default:
            CGSize(width: cgImage.width, height: cgImage.height)
        }
    }

    private static func isDecodableImageData(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ),
        CGImageSourceGetCount(source) > 0,
        let properties = CGImageSourceCopyPropertiesAtIndex(
            source,
            0,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) as? [CFString: Any],
        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
        width > 0,
        height > 0
        else {
            return false
        }
        return true
    }
}

nonisolated enum CameraCaptureResultError: Error, Equatable {
    case unreadableCapture
}
