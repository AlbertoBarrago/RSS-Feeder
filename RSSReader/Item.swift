//
//  Item.swift
//  RSSReader
//
//  Created by Alberto Barrago on 28/08/25.
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
