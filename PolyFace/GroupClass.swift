//
//  GroupClass.swift
//  PolyFace
//
//  Created by Assistant on 12/31/25.
//

import Foundation

struct GroupClass: Identifiable, Codable, Hashable {
    var id: String?
    let title: String
    let description: String
    let startTime: Date
    let endTime: Date
    let maxParticipants: Int
    var currentParticipants: Int
    let location: String
    let isOpenForRegistration: Bool
    let createdBy: String // Admin user ID
    let createdAt: Date
    
    var isFull: Bool {
        currentParticipants >= maxParticipants
    }
    
    var spotsRemaining: Int {
        max(0, maxParticipants - currentParticipants)
    }
    
    var isUpcoming: Bool {
        startTime > Date()
    }
}
