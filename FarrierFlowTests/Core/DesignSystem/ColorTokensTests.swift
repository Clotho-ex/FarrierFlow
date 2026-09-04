import SwiftUI
import Testing
import UIKit
@testable import FarrierFlow

@Suite("FarrierFlow color tokens")
@MainActor
struct ColorTokensTests {
    @Test
    func swiftUISurfacesFollowTheirAppearanceEnvironment() {
        var environment = EnvironmentValues()
        environment.colorScheme = .light
        #expect(abs(ColorTokens.background.resolve(in: environment).red - 244.0 / 255) < 0.001)
        #expect(abs(ColorTokens.brandPrimary.resolve(in: environment).red - 191.0 / 255) < 0.001)
        environment.colorScheme = .dark
        #expect(abs(ColorTokens.background.resolve(in: environment).red - 23.0 / 255) < 0.001)
        #expect(abs(ColorTokens.brandPrimary.resolve(in: environment).red - 224.0 / 255) < 0.001)
    }

    @Test
    func dynamicColorsResolveOnBackgroundRenderer() async {
        let colors = [
            ColorTokens.Palette.brandPrimary, ColorTokens.Palette.brandActionText,
            ColorTokens.Palette.background, ColorTokens.Palette.surface, ColorTokens.Palette.textPrimary,
            ColorTokens.Palette.successTint, ColorTokens.Palette.warningTint, ColorTokens.Palette.destructiveTint,
            ElevationTokens.raisedShadowColor,
        ]

        let allResolved = await Task.detached {
            let traits = UITraitCollection(userInterfaceStyle: .dark)
            var allResolved = false
            traits.performAsCurrent {
                allResolved = colors.allSatisfy { color in
                    var red: CGFloat = 0
                    var green: CGFloat = 0
                    var blue: CGFloat = 0
                    var alpha: CGFloat = 0
                    return color.resolvedColor(with: traits)
                        .getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                        && alpha > 0
                }
            }
            return allResolved
        }.value
        #expect(allResolved)
    }

    @Test
    func lightModeUsesApprovedBrandNeutralAndSemanticColors() {
        let traits = UITraitCollection(userInterfaceStyle: .light)

        expect(ColorTokens.Palette.brandPrimary, hex: 0xBF5700, traits: traits)
        expect(ColorTokens.Palette.background, hex: 0xF4F0EB, traits: traits)
        expect(ColorTokens.Palette.surface, hex: 0xFAF8F5, traits: traits)
        expect(ColorTokens.Palette.textPrimary, hex: 0x24211E, traits: traits)
        expect(ColorTokens.Palette.textSecondary, hex: 0x5F5953, traits: traits)
        expect(ColorTokens.Palette.textMuted, hex: 0x8D867F, traits: traits)
        expect(ColorTokens.Palette.border, hex: 0xDDD7D1, traits: traits)
        expect(ColorTokens.Palette.success, hex: 0x287A4B, traits: traits)
        expect(ColorTokens.Palette.warning, hex: 0xB97800, traits: traits)
        expect(ColorTokens.Palette.destructive, hex: 0xB83A36, traits: traits)
        expect(ColorTokens.Palette.information, hex: 0x416B78, traits: traits)
    }

    @Test
    func darkModeUsesApprovedWarmCharcoalPalette() {
        let traits = UITraitCollection(userInterfaceStyle: .dark)

        expect(ColorTokens.Palette.brandPrimary, hex: 0xE06C12, traits: traits)
        expect(ColorTokens.Palette.background, hex: 0x171513, traits: traits)
        expect(ColorTokens.Palette.surface, hex: 0x211E1B, traits: traits)
        expect(ColorTokens.Palette.surfaceElevated, hex: 0x2A2622, traits: traits)
        expect(ColorTokens.Palette.textPrimary, hex: 0xF5F1EC, traits: traits)
        expect(ColorTokens.Palette.textSecondary, hex: 0xB8B0A8, traits: traits)
        expect(ColorTokens.Palette.border, hex: 0x39332E, traits: traits)
        expect(ColorTokens.Palette.brandTint, hex: 0x3B2516, traits: traits)
        expect(ColorTokens.Palette.success, hex: 0x58A978, traits: traits)
        expect(ColorTokens.Palette.warning, hex: 0xD9A13B, traits: traits)
        expect(ColorTokens.Palette.destructive, hex: 0xE06964, traits: traits)
        expect(ColorTokens.Palette.successTint, hex: 0x2A342A, traits: traits)
        expect(ColorTokens.Palette.warningTint, hex: 0x3E3320, traits: traits)
        expect(ColorTokens.Palette.destructiveTint, hex: 0x402A27, traits: traits)
    }

    @Test
    func actionLabelsMeetTextContrastInBothAppearances() {
        for style: UIUserInterfaceStyle in [.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            #expect(contrast(ColorTokens.Palette.brandPrimary, ColorTokens.Palette.onBrand, traits: traits) >= 4.5)
            #expect(contrast(ColorTokens.Palette.brandActionText, ColorTokens.Palette.brandTint, traits: traits) >= 4.5)
            #expect(contrast(ColorTokens.Palette.textPrimary, ColorTokens.Palette.background, traits: traits) >= 7)
            #expect(contrast(ColorTokens.Palette.textSecondary, ColorTokens.Palette.surface, traits: traits) >= 4.5)
            #expect(contrast(ColorTokens.Palette.success, ColorTokens.Palette.successTint, traits: traits) >= 4.5)
        }
    }

    private func contrast(_ first: UIColor, _ second: UIColor, traits: UITraitCollection) -> CGFloat {
        func luminance(_ color: UIColor) -> CGFloat {
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            resolvedColor(color, traits: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            #expect(alpha == 1, "Contrast pairs must use opaque colors, independent of their parent surface.")
            func linear(_ value: CGFloat) -> CGFloat {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return linear(red) * 0.2126 + linear(green) * 0.7152 + linear(blue) * 0.0722
        }
        let a = luminance(first)
        let b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    @Test
    func increasedContrastStrengthensActionSecondaryTextAndBorders() {
        let lightTraits = UITraitCollection { traits in
            traits.userInterfaceStyle = .light
            traits.accessibilityContrast = .high
        }
        let darkTraits = UITraitCollection { traits in
            traits.userInterfaceStyle = .dark
            traits.accessibilityContrast = .high
        }

        expect(ColorTokens.Palette.brandPrimary, hex: 0x8F4100, traits: lightTraits)
        expect(ColorTokens.Palette.brandPrimary, hex: 0xE57820, traits: darkTraits)
        expect(ColorTokens.Palette.textMuted, hex: 0x5F5953, traits: lightTraits)
        expect(ColorTokens.Palette.textMuted, hex: 0xB8B0A8, traits: darkTraits)
        expect(ColorTokens.Palette.border, hex: 0x8D867F, traits: lightTraits)
        expect(ColorTokens.Palette.border, hex: 0xB8B0A8, traits: darkTraits)
    }

    private func expect(
        _ color: UIColor,
        hex: UInt32,
        traits: UITraitCollection,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let resolved = resolvedColor(color, traits: traits)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        #expect(
            resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha),
            sourceLocation: sourceLocation
        )

        let expectedRed = CGFloat((hex >> 16) & 0xFF) / 255
        let expectedGreen = CGFloat((hex >> 8) & 0xFF) / 255
        let expectedBlue = CGFloat(hex & 0xFF) / 255
        #expect(abs(red - expectedRed) < 0.001, sourceLocation: sourceLocation)
        #expect(abs(green - expectedGreen) < 0.001, sourceLocation: sourceLocation)
        #expect(abs(blue - expectedBlue) < 0.001, sourceLocation: sourceLocation)
        #expect(abs(alpha - 1) < 0.001, sourceLocation: sourceLocation)
    }

    private func resolvedColor(_ color: UIColor, traits: UITraitCollection) -> UIColor {
        color.resolvedColor(with: traits)
    }
}
