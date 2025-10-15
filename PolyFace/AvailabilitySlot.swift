//
//  AvailabilitySlot.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import Foundation

// trainers/{trainerId}/schedules/{slotId}
struct AvailabilitySlot: Identifiable, Hashable {
    var id: String?
    var trainerId: String?
    var title: String?
    var status: String?
    var startTime: Date
    var endTime: Date

    enum CodingKeys: String, CodingKey {
        case id, trainerId, title, status, startTime, endTime
    }

    var displayTitle: String { (title?.isEmpty == false) ? title! : "Private Lesson" }

    // Convenience for UI filtering/labels
    var isOpen: Bool { status == "open" }
    var isBooked: Bool { status == "booked" }
    var duration: TimeInterval { endTime.timeIntervalSince(startTime) }
}
