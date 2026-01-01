//
//  Item.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/12/25.
//

import Foundation

#if SWIFTDATA_ENABLED
import SwiftData

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
@Model
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
#else
// Fallback definition for builds where SwiftData is excluded (e.g., iOS 15/16)
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
#endif
