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
