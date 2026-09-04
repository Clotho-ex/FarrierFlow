//
//  ColorTokens.swift
//  FarrierFlow
//
//  Created by Yusufcan Var on 26.07.2026.
//

import SwiftUI
import UIKit

// UIKit may resolve dynamic colors on SwiftUI's asynchronous rendering thread.
nonisolated enum ColorTokens {
    static let brandPrimary = Color(uiColor: Palette.brandPrimary)
    static let brandPrimaryPressed = Color(uiColor: Palette.brandPrimaryPressed)
    static let brandActionText = Color(uiColor: Palette.brandActionText)
    static let onBrand = Color(uiColor: Palette.onBrand)
    static let brandPrimaryLight = Color(uiColor: Palette.brandPrimaryLight)
    static let brandTint = Color(uiColor: Palette.brandTint)
    static let background = Color(uiColor: Palette.background)
    static let surface = Color(uiColor: Palette.surface)
    static let surfaceElevated = Color(uiColor: Palette.surfaceElevated)
    static let textPrimary = Color(uiColor: Palette.textPrimary)
    static let textSecondary = Color(uiColor: Palette.textSecondary)
    static let textMuted = Color(uiColor: Palette.textMuted)
    static let border = Color(uiColor: Palette.border)
    static let success = Color(uiColor: Palette.success)
    static let successTint = Color(uiColor: Palette.successTint)
    static let warning = Color(uiColor: Palette.warning)
    static let warningTint = Color(uiColor: Palette.warningTint)
    static let destructive = Color(uiColor: Palette.destructive)
    static let destructiveTint = Color(uiColor: Palette.destructiveTint)
    static let information = Color(uiColor: Palette.information)

    // Keep the native dynamic providers available without a lossy Color-to-UIColor round trip.
    nonisolated enum Palette {
        static let brandPrimary = dynamic(
            light: 0xBF5700,
            dark: 0xE06C12,
            increasedLight: 0x8F4100,
            increasedDark: 0xE57820
        )
        static let brandPrimaryPressed = dynamic(light: 0x8F4100, dark: 0xBF5700)
        // Small action text needs stronger contrast on brand-tinted surfaces than the button fill.
        static let brandActionText = dynamic(light: 0x8F4100, dark: 0xE57820)
        static let onBrand = dynamic(light: 0xFFFFFF, dark: 0x24211E)
        static let brandPrimaryLight = dynamic(light: 0xE57820, dark: 0xE57820)
        static let brandTint = dynamic(light: 0xFFF1E6, dark: 0x3B2516)

        static let background = dynamic(light: 0xF4F0EB, dark: 0x171513)
        static let surface = dynamic(light: 0xFAF8F5, dark: 0x211E1B)
        static let surfaceElevated = dynamic(light: 0xFFFFFF, dark: 0x2A2622)

        static let textPrimary = dynamic(light: 0x24211E, dark: 0xF5F1EC)
        static let textSecondary = dynamic(light: 0x5F5953, dark: 0xB8B0A8)
        static let textMuted = dynamic(
            light: 0x8D867F,
            dark: 0x8D867F,
            increasedLight: 0x5F5953,
            increasedDark: 0xB8B0A8
        )
        static let border = dynamic(
            light: 0xDDD7D1,
            dark: 0x39332E,
            increasedLight: 0x8D867F,
            increasedDark: 0xB8B0A8
        )

        static let success = dynamic(light: 0x287A4B, dark: 0x58A978)
        static let successTint = dynamic(
            light: 0xE8F4EC,
            dark: 0x2A342A
        )
        static let warning = dynamic(light: 0xB97800, dark: 0xD9A13B)
        static let warningTint = dynamic(
            light: 0xFFF3D7,
            dark: 0x3E3320
        )
        static let destructive = dynamic(light: 0xB83A36, dark: 0xE06964)
        static let destructiveTint = dynamic(
            light: 0xFCE9E7,
            dark: 0x402A27
        )
        static let information = dynamic(
            light: 0x416B78,
            dark: blendedHex(0x416B78, with: 0xF5F1EC, amount: 0.35)
        )

        private static func dynamic(
            light: UInt32,
            dark: UInt32,
            increasedLight: UInt32? = nil,
            increasedDark: UInt32? = nil,
            lightAlpha: CGFloat = 1,
            darkAlpha: CGFloat = 1
        ) -> UIColor {
            UIColor { traits in
                let isDark = traits.userInterfaceStyle == .dark
                let isIncreased = traits.accessibilityContrast == .high
                let hex: UInt32
                if isDark {
                    hex = isIncreased ? increasedDark ?? dark : dark
                } else {
                    hex = isIncreased ? increasedLight ?? light : light
                }
                return uiColor(
                    hex: hex,
                    alpha: isDark ? darkAlpha : lightAlpha
                )
            }
        }

        private static func uiColor(hex: UInt32, alpha: CGFloat) -> UIColor {
            UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: alpha
            )
        }

        private static func blendedHex(
            _ base: UInt32,
            with overlay: UInt32,
            amount: Double
        ) -> UInt32 {
            let baseRed = Double((base >> 16) & 0xFF)
            let baseGreen = Double((base >> 8) & 0xFF)
            let baseBlue = Double(base & 0xFF)
            let overlayRed = Double((overlay >> 16) & 0xFF)
            let overlayGreen = Double((overlay >> 8) & 0xFF)
            let overlayBlue = Double(overlay & 0xFF)

            let red = UInt32((baseRed + (overlayRed - baseRed) * amount).rounded())
            let green = UInt32((baseGreen + (overlayGreen - baseGreen) * amount).rounded())
            let blue = UInt32((baseBlue + (overlayBlue - baseBlue) * amount).rounded())
            return (red << 16) | (green << 8) | blue
        }
    }
}
