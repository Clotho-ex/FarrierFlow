//
//  ColorTokens.swift
//  FarrierFlow
//
//  Created by Yusufcan Var on 26.07.2026.
//

import SwiftUI
import UIKit

enum ColorTokens {
    static let interactive = Color.accentColor
    static let surveyInk = Color(
        uiColor: UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                UIColor(red: 0.08, green: 0.23, blue: 0.22, alpha: 1)
            } else {
                UIColor(red: 0.098, green: 0.365, blue: 0.349, alpha: 1)
            }
        }
    )
}
