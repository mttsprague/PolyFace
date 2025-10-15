//
//  BookingCallError.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import Foundation
import Combine
import FirebaseFunctions
import FirebaseAuth
import FirebaseFirestore

enum BookingCallError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case server(String)
    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "You must be logged in to book a lesson."
        case .invalidResponse: return "Unexpected response from the server."
        case .server(let message): return message
        }
    }
}

@MainActor
final class BookingManager: ObservableObject {
    private let functions = Functions.functions()

    func bookLesson(trainerId: String, slotId: String, lessonPackageId: String) async throws -> Booking {
        guard let user = Auth.auth().currentUser else { throw BookingCallError.notAuthenticated }

        // Debug prints to verify what we send to the Cloud Function
        print("BookingManager.bookLesson → Calling CF 'bookLesson'")
        print("  trainerId: \(trainerId)")
        print("  slotId: \(slotId)")
        print("  lessonPackageId: \(lessonPackageId)")
        print("  clientUID: \(user.uid)")
        print("  clientName: \(user.displayName ?? "N/A")")

        // The CF ignores clientUID/clientName; keep payload minimal and aligned with server contract
        let payload: [String: Any] = [
            "trainerId": trainerId,
            "slotId": slotId,
            "lessonPackageId": lessonPackageId
        ]

        let result = try await functions.httpsCallable("bookLesson").call(payload)

        guard let dict = result.data as? [String: Any] else {
            print("BookingManager.bookLesson → Invalid response shape. Raw data: \(String(describing: result.data))")
            throw BookingCallError.invalidResponse
        }

        // If server chose to embed an error field (unlikely with HttpsError), surface it
        if let errMsg = dict["error"] as? String {
            print("BookingManager.bookLesson → Server error: \(errMsg)")
            throw BookingCallError.server(errMsg)
        }

        // Preferred: server returns a "booking" dictionary
        if let bookingDict = dict["booking"] as? [String: Any] {
            let booking = try decodeBooking(from: bookingDict)
            print("BookingManager.bookLesson → Success. Booking id: \(booking.id ?? "<nil>")")
            return booking
        }

        // Fallback: current server returns only { message: "..." }
        if let message = dict["message"] as? String {
            print("BookingManager.bookLesson → Success message: \(message)")
            // Return a minimal booking; UI doesn't rely on it in BookView.performBooking
            return Booking(
                id: nil,
                clientUID: user.uid,
                trainerUID: trainerId,                 // align with Booking model naming
                scheduleSlotId: slotId,
                lessonPackageId: lessonPackageId,
                startTime: nil,
                endTime: nil,
                status: "confirmed",
                createdAt: nil,
                updatedAt: nil
            )
        }

        print("BookingManager.bookLesson → Missing 'booking' and 'message' in response: \(dict)")
        throw BookingCallError.invalidResponse
    }

    private func decodeBooking(from dict: [String: Any]) throws -> Booking {
        func date(from any: Any?) -> Date? {
            if let ts = any as? Timestamp { return ts.dateValue() }
            if let d = any as? Date { return d }
            if let tdict = any as? [String: Any], let seconds = tdict["_seconds"] as? TimeInterval {
                return Date(timeIntervalSince1970: seconds)
            }
            return nil
        }
        return Booking(
            id: dict["id"] as? String,
            clientUID: dict["clientUID"] as? String ?? "",
            trainerUID: dict["trainerUID"] as? String ?? dict["trainerId"] as? String ?? "",
            scheduleSlotId: dict["scheduleSlotId"] as? String ?? dict["slotId"] as? String,
            lessonPackageId: dict["lessonPackageId"] as? String ?? dict["packageId"] as? String,
            startTime: date(from: dict["startTime"]),
            endTime: date(from: dict["endTime"]),
            status: dict["status"] as? String ?? "confirmed",
            // Accept either createdAt/updatedAt or bookedAt (server currently writes bookedAt)
            createdAt: date(from: dict["createdAt"] ?? dict["bookedAt"]),
            updatedAt: date(from: dict["updatedAt"] ?? dict["bookedAt"])
        )
    }
}

