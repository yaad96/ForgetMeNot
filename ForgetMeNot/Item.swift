//
//  Item.swift
//  ForgetMeNot
//
//  Created by Mainul Hossain on 8/3/25.
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
