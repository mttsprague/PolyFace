// BookingManager.swift
import Foundation
import StoreKit
import Combine
import FirebaseFunctions
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class BookingManager: ObservableObject {
    private let functions = Functions.functions()
    private let db = Firestore.firestore()

    // If lessonPackageId is provided and non-empty, use it directly.
    // Otherwise, automatically choose the package with the closest expiration date.
    func bookLesson(trainerId: String, slotId: String, lessonPackageId: String) async throws -> Booking {
        guard let user = Auth.auth().currentUser else { throw BookingCallError.notAuthenticated }
        let uid = user.uid

        // 1) Determine which package to use
        let packageId: String
        if !lessonPackageId.isEmpty {
            // User explicitly selected a package
            packageId = lessonPackageId
        } else {
            // Auto-select the package that expires the soonest but is still valid
            guard let chosenId = try await chooseSoonestExpiringPackageId(for: uid) else {
                throw BookingCallError.noAvailablePackage
            }
            packageId = chosenId
        }

        // Debug prints to verify what we send to the Cloud Function
        print("BookingManager.bookLesson → Calling CF 'bookLesson'")
        print("  trainerId: \(trainerId)")
        print("  slotId: \(slotId)")
        print("  chosenPackageId: \(packageId)")
        print("  clientUID: \(uid)")
        print("  clientName: \(user.displayName ?? "N/A")")

        // 2) Call Cloud Function using the chosen package.
        let payload: [String: Any] = [
            "trainerId": trainerId,
            "slotId": slotId,
            "lessonPackageId": packageId
        ]
        let result = try await functions.httpsCallable("bookLesson").call(payload)

        // 3) Decode server response
        guard let dict = result.data as? [String: Any] else {
            print("BookingManager.bookLesson → Invalid response shape. Raw data: \(String(describing: result.data))")
            throw BookingCallError.invalidResponse
        }
        if let errMsg = dict["error"] as? String {
            print("BookingManager.bookLesson → Server error: \(errMsg)")
            throw BookingCallError.server(errMsg)
        }

        // IMPORTANT: Do not update lessonPackages from the client.
        // The Cloud Function must perform lessonsUsed increment and any related writes.

        if let bookingDict = dict["booking"] as? [String: Any] {
            let booking = try decodeBooking(from: bookingDict)
            print("BookingManager.bookLesson → Success. Booking id: \(booking.id ?? "<nil>")")
            return booking
        }

        if let message = dict["message"] as? String {
            print("BookingManager.bookLesson → Success message: \(message)")
            return Booking(
                id: nil,
                clientUID: uid,
                trainerUID: trainerId,
                scheduleSlotId: slotId,
                lessonPackageId: packageId,
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

    // MARK: - Package selection

    private func chooseSoonestExpiringPackageId(for uid: String) async throws -> String? {
        let snap = try await db.collection("users")
            .document(uid)
            .collection("lessonPackages")
            .order(by: "expirationDate", descending: false) // earliest first
            .getDocuments()

        let now = Date()

        // Decode minimal fields we need to compute remaining and validity
        struct Pkg {
            let id: String
            let total: Int
            let used: Int
            let expiration: Date
        }

        func date(from any: Any?) -> Date? {
            if let ts = any as? Timestamp { return ts.dateValue() }
            if let d = any as? Date { return d }
            if let dict = any as? [String: Any], let seconds = dict["_seconds"] as? TimeInterval {
                return Date(timeIntervalSince1970: seconds)
            }
            return nil
        }

        let pkgs: [Pkg] = snap.documents.compactMap { doc in
            let data = doc.data()
            guard
                let packageType = data["packageType"] as? String,
                packageType != "class_pass", // Exclude class passes - they can only be used for classes
                let total = data["totalLessons"] as? Int,
                let used = data["lessonsUsed"] as? Int,
                let exp = date(from: data["expirationDate"])
            else { return nil }
            return Pkg(id: doc.documentID, total: total, used: used, expiration: exp)
        }

        // Pick the first package that is not expired and has remaining > 0
        let chosen = pkgs.first { pkg in
            pkg.expiration >= now && (pkg.total - pkg.used) > 0
        }

        return chosen?.id
    }

    // MARK: - Decode booking helper

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
