import SwiftUI
import UIKit

nonisolated enum ElevationTokens {
    static let raisedShadowColor = UIColor { traits in
        UIColor.black.withAlphaComponent(
            traits.userInterfaceStyle == .dark ? 0.30 : 0.11
        )
    }
    static let raisedShadow = Color(uiColor: raisedShadowColor)
    static let raisedRadius: CGFloat = 11
    static let raisedY: CGFloat = 5
}

extension View {
    func fieldBookElevation() -> some View {
        shadow(
            color: ElevationTokens.raisedShadow,
            radius: ElevationTokens.raisedRadius,
            x: 0,
            y: ElevationTokens.raisedY
        )
    }
}
