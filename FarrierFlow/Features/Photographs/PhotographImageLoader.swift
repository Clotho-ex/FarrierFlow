import Foundation
import ImageIO
import UIKit

nonisolated struct PhotographImageLoader: Sendable {
    func load(url: URL, maximumPixelSize: Int) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard maximumPixelSize > 0,
                  let values = try? url.resourceValues(
                    forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
                  ),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  let source = CGImageSourceCreateWithURL(
                    url as CFURL,
                    [kCGImageSourceShouldCache: false] as CFDictionary
                  ),
                  let image = CGImageSourceCreateThumbnailAtIndex(
                    source,
                    0,
                    [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                        kCGImageSourceShouldCacheImmediately: true,
                    ] as CFDictionary
                  )
            else {
                return nil
            }
            return UIImage(cgImage: image)
        }.value
    }
}
