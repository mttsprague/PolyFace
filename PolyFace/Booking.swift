//
//  Booking.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import Foundation

// booking documents (top-level /bookings)
struct Booking: Identifiable {
    var id: String?
    let clientUID: String
    let trainerUID: String
    let scheduleSlotId: String?
    let lessonPackageId: String?
    let startTime: Date?
    let endTime: Date?
    let status: String
    let createdAt: Date?
    let updatedAt: Date?
}
