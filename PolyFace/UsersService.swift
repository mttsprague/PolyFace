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
            print("UsersService: No authenticated user")
            currentUser = nil
            return
        }
        
        print("UsersService: Loading profile for UID: \(uid)")
        do {
            let snapshot = try await db.collection("users").document(uid).getDocument()
            if snapshot.exists, let data = snapshot.data() {
                print("UsersService: ✅ User document found")
                currentUser = decodeUserProfile(id: snapshot.documentID, data: data)
            } else {
                print("UsersService: ❌ User document does NOT exist for UID: \(uid)")
                print("UsersService: This usually means the Firebase Auth UID doesn't match any Firestore user document.")
                print("UsersService: Automatically signing out to clear cached auth token...")
                currentUser = nil
                
                // Force sign out to clear the cached auth token
                try? Auth.auth().signOut()
            }
        } catch {
            print("UsersService: ❌ Error loading user profile: \(error)")
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
            athlete3FirstName: data["athlete3FirstName"] as? String,
            athlete3LastName: data["athlete3LastName"] as? String,
            athletePosition: data["athletePosition"] as? String,
            athlete2Position: data["athlete2Position"] as? String,
            athlete3Position: data["athlete3Position"] as? String,
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
        athlete3FirstName: String?,
        athlete3LastName: String?,
        athletePosition: String?,
        athlete2Position: String?,
        athlete3Position: String?,
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
        if let athlete3FirstName = athlete3FirstName {
            updateData["athlete3FirstName"] = athlete3FirstName
        }
        if let athlete3LastName = athlete3LastName {
            updateData["athlete3LastName"] = athlete3LastName
        }
        if let athletePosition = athletePosition {
            updateData["athletePosition"] = athletePosition
        }
        if let athlete2Position = athlete2Position {
            updateData["athlete2Position"] = athlete2Position
        }
        if let athlete3Position = athlete3Position {
            updateData["athlete3Position"] = athlete3Position
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
