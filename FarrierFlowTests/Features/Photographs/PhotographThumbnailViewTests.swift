import SwiftUI
import Testing
import UIKit
@testable import FarrierFlow

@Suite("Photograph thumbnail view")
@MainActor
struct PhotographThumbnailViewTests {
    @Test
    func portraitAndLandscapeImagesUseTheSameSquareFootprint() {
        let proposedSize = CGSize(
            width: 160,
            height: CGFloat.greatestFiniteMagnitude
        )
        let landscapeSize = fittedSize(
            for: image(width: 400, height: 100),
            proposedSize: proposedSize
        )
        let portraitSize = fittedSize(
            for: image(width: 100, height: 400),
            proposedSize: proposedSize
        )

        #expect(landscapeSize == CGSize(width: 160, height: 160))
        #expect(portraitSize == landscapeSize)
    }

    private func fittedSize(
        for image: UIImage,
        proposedSize: CGSize
    ) -> CGSize {
        let controller = UIHostingController(
            rootView: PhotographThumbnailContentView(
                image: image,
                showsUnavailableState: false
            )
        )
        return controller.sizeThatFits(in: proposedSize)
    }

    private func image(width: CGFloat, height: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image {
            $0.cgContext.setFillColor(UIColor.brown.cgColor)
            $0.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
