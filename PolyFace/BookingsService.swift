//
//  BookingsService.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class BookingsService: ObservableObject {
    @Published private(set) var myBookings: [Booking] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let db = Firestore.firestore()

    func loadMyBookings(limit: Int = 50) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            myBookings = []
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let snap = try await db.collection("bookings")
                .whereField("clientUID", isEqualTo: uid)
                .order(by: "startTime", descending: false)
                .limit(to: limit)
                .getDocuments()

            myBookings = snap.documents.compactMap { doc in
                decodeBooking(id: doc.documentID, data: doc.data())
            }
        } catch {
            errorMessage = error.localizedDescription
            myBookings = []
        }
        isLoading = false
    }

    private func decodeBooking(id: String, data: [String: Any]) -> Booking {
        Booking(
            id: id,
            clientUID: data["clientUID"] as? String ?? "",
            // Accept either trainerUID (old) or trainerId (server currently writes)
            trainerUID: (data["trainerUID"] as? String) ?? (data["trainerId"] as? String) ?? "",
            // Accept either scheduleSlotId (old) or slotId (server currently writes)
            scheduleSlotId: (data["scheduleSlotId"] as? String) ?? (data["slotId"] as? String),
            // Accept either lessonPackageId (old) or packageId (server currently writes)
            lessonPackageId: (data["lessonPackageId"] as? String) ?? (data["packageId"] as? String),
            startTime: Self.date(from: data["startTime"]),
            endTime: Self.date(from: data["endTime"]),
            status: data["status"] as? String ?? "confirmed",
            // Accept createdAt/updatedAt or fall back to bookedAt
            createdAt: Self.date(from: data["createdAt"] ?? data["bookedAt"]),
            updatedAt: Self.date(from: data["updatedAt"] ?? data["bookedAt"])
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

