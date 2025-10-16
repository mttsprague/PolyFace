//
//  PackagesService.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class PackagesService: ObservableObject {
    @Published private(set) var packages: [LessonPackage] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let db = Firestore.firestore()

    func loadMyPackages() async {
        guard let uid = Auth.auth().currentUser?.uid else { packages = []; return }
        isLoading = true
        errorMessage = nil
        do {
            let snap = try await db.collection("users").document(uid)
                .collection("lessonPackages")
                .order(by: "purchaseDate", descending: true)
                .getDocuments()
            packages = snap.documents.compactMap { doc in
                decodePackage(id: doc.documentID, data: doc.data())
            }
        } catch {
            errorMessage = error.localizedDescription
            packages = []
        }
        isLoading = false
    }

    var hasAvailableLessons: Bool {
        packages.contains { $0.lessonsRemaining > 0 && $0.expirationDate >= Date() }
    }

    // Create a new lesson package document under the signed-in user.
    // This conforms to the rule requirements:
    // - lessonsUsed = 0 on creation
    // - allowed packageType: single | five_pack | ten_pack
    // - allowed totalLessons: 1 | 5 | 10
    // - purchaseDate/expirationDate are Dates (serialized as Firestore Timestamps)
    func createLessonPackage(packageType: String,
                             totalLessons: Int,
                             purchaseDate: Date,
                             expirationDate: Date,
                             transactionId: String?) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "PackagesService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }

        let payload: [String: Any?] = [
            "packageType": packageType,        // "single" | "five_pack" | "ten_pack"
            "totalLessons": totalLessons,      // 1 | 5 | 10
            "lessonsUsed": 0,                  // must be 0 on create per rules
            "purchaseDate": purchaseDate,      // Firestore will store as Timestamp
            "expirationDate": expirationDate,  // Firestore will store as Timestamp
            "transactionId": transactionId
        ]

        // Compact out nils for Firestore
        let data = payload.compactMapValues { $0 }

        try await db.collection("users")
            .document(uid)
            .collection("lessonPackages")
            .addDocument(data: data)
    }

    private func decodePackage(id: String, data: [String: Any]) -> LessonPackage? {
        guard
            let packageType = data["packageType"] as? String,
            let totalLessons = data["totalLessons"] as? Int,
            let lessonsUsed = data["lessonsUsed"] as? Int,
            let purchaseDate = Self.date(from: data["purchaseDate"]),
            let expirationDate = Self.date(from: data["expirationDate"])
        else {
            return nil
        }
        return LessonPackage(
            id: id,
            packageType: packageType,
            totalLessons: totalLessons,
            lessonsUsed: lessonsUsed,
            purchaseDate: purchaseDate,
            expirationDate: expirationDate,
            transactionId: data["transactionId"] as? String
        )
    }

    private static func date(from any: Any?) -> Date? {
        if let ts = any as? Timestamp { return ts.dateValue() }
        if let d = any as? Date { return d }
        if let dict = any as? [String: Any], let seconds = dict["_seconds"] as? TimeInterval {
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }
}

