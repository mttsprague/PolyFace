//
//  UsersService.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class UsersService: ObservableObject {
    @Published private(set) var currentUser: UserProfile?

    private let db = Firestore.firestore()

    func loadCurrentUserIfAvailable() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            currentUser = nil
            return
        }
        do {
            let snapshot = try await db.collection("users").document(uid).getDocument()
            if snapshot.exists, let data = snapshot.data() {
                currentUser = decodeUserProfile(id: snapshot.documentID, data: data)
            } else {
                currentUser = nil
            }
        } catch {
            print("UsersService: failed to load user profile: \(error)")
            currentUser = nil
        }
    }

    private func decodeUserProfile(id: String, data: [String: Any]) -> UserProfile {
        UserProfile(
            id: id,
            emailAddress: data["emailAddress"] as? String,
            firstName: data["firstName"] as? String,
            lastName: data["lastName"] as? String,
            athleteFirstName: data["athleteFirstName"] as? String,
            athleteLastName: data["athleteLastName"] as? String,
            athlete2FirstName: data["athlete2FirstName"] as? String,
            athlete2LastName: data["athlete2LastName"] as? String,
            athletePosition: data["athletePosition"] as? String,
            athlete2Position: data["athlete2Position"] as? String,
            notesForCoach: data["notesForCoach"] as? String,
            phoneNumber: data["phoneNumber"] as? String,
            photoURL: data["photoURL"] as? String,
            active: data["active"] as? Bool,
            createdAt: Self.date(from: data["createdAt"]),
            updatedAt: Self.date(from: data["updatedAt"])
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
    
    var currentUserProfile: UserProfile? {
        return currentUser
    }
    
    func updateUserProfile(
        firstName: String,
        lastName: String,
        athleteFirstName: String,
        athleteLastName: String,
        athlete2FirstName: String?,
        athlete2LastName: String?,
        athletePosition: String?,
        athlete2Position: String?,
        notesForCoach: String?,
        emailAddress: String,
        phoneNumber: String?
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "UsersService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        var updateData: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "athleteFirstName": athleteFirstName,
            "athleteLastName": athleteLastName,
            "emailAddress": emailAddress,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        // Add optional fields
        if let athlete2FirstName = athlete2FirstName {
            updateData["athlete2FirstName"] = athlete2FirstName
        }
        if let athlete2LastName = athlete2LastName {
            updateData["athlete2LastName"] = athlete2LastName
        }
        if let athletePosition = athletePosition {
            updateData["athletePosition"] = athletePosition
        }
        if let athlete2Position = athlete2Position {
            updateData["athlete2Position"] = athlete2Position
        }
        if let notesForCoach = notesForCoach {
            updateData["notesForCoach"] = notesForCoach
        }
        if let phoneNumber = phoneNumber {
            updateData["phoneNumber"] = phoneNumber
        }
        
        try await db.collection("users").document(uid).updateData(updateData)
        
        // Reload the profile after update
        await loadCurrentUserIfAvailable()
    }
}
