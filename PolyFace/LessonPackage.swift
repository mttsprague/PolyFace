//
//  LessonPackage.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import Foundation

// /users/{uid}/lessonPackages/{packageId}
struct LessonPackage: Identifiable, Equatable {
    var id: String?
    let packageType: String
    let totalLessons: Int
    var lessonsUsed: Int
    let purchaseDate: Date
    let expirationDate: Date
    let transactionId: String?

    var lessonsRemaining: Int { totalLessons - lessonsUsed }

    // Convenience used by some UI examples
    var isValidAndAvailable: Bool {
        lessonsRemaining > 0 && expirationDate >= Date()
    }
}
