//
//  Item.swift
//  interactive-lessons
//
//  Created by Oliver Cameron on 7/9/26.
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
