//
//  Item.swift
//  FarrierFlow
//
//  Created by Yusufcan Var on 26.07.2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
