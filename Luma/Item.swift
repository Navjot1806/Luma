//
//  Item.swift
//  Luma
//
//  Created by Navjyotsingh Multani on 1/12/26.
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
