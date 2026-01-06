import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var authError: String?

    // Option B: No anonymous sign-in. Just mark the app ready to present UI.
    func ensureSignedIn() async {
        isReady = true
    }

    func signIn(email: String, password: String) async -> Bool {
        authError = nil // Clear any stale errors before starting
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            authError = nil
            return true
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    func register(email: String,
                  password: String,
                  firstName: String?,
                  lastName: String?,
                  athleteFirstName: String?,
                  athleteLastName: String?,
                  athlete2FirstName: String?,
                  athlete2LastName: String?,
                  athlete3FirstName: String?,
                  athlete3LastName: String?,
                  athletePosition: String?,
                  athlete2Position: String?,
                  athlete3Position: String?,
                  notesForCoach: String?,
                  phoneNumber: String?) async -> Bool {
        authError = nil // Clear any stale errors before starting
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid

            let db = Firestore.firestore()
            let now = Date()
            let data: [String: Any?] = [
                "emailAddress": email,
                "firstName": firstName,
                "lastName": lastName,
                "athleteFirstName": athleteFirstName,
                "athleteLastName": athleteLastName,
                "athlete2FirstName": athlete2FirstName,
                "athlete2LastName": athlete2LastName,
                "athlete3FirstName": athlete3FirstName,
                "athlete3LastName": athlete3LastName,
                "athletePosition": athletePosition,
                "athlete2Position": athlete2Position,
                "athlete3Position": athlete3Position,
                "notesForCoach": notesForCoach,
                "phoneNumber": phoneNumber,
                "photoURL": nil,
                "active": true,
                "createdAt": now,
                "updatedAt": now
            ]

            // Debug: Show payload and auth state at write time
            let payload = data.compactMapValues { $0 }
            let currentUID = Auth.auth().currentUser?.uid ?? "<nil>"
            print("AuthManager.register → Attempting setData for uid=\(uid)")
            print("AuthManager.register → Current Auth UID at write time: \(currentUID) (matches: \(currentUID == uid))")
            print("AuthManager.register → Payload: \(payload)")

            try await db.collection("users").document(uid).setData(payload)
            authError = nil
            print("AuthManager.register → setData succeeded for uid=\(uid)")
            return true
        } catch {
            // Print full NSError details so we can see domain/code/userInfo
            let ns = error as NSError
            print("AuthManager.register → ERROR during setData")
            print("  Error: \(error)")
            print("  Domain: \(ns.domain)")
            print("  Code: \(ns.code)")
            print("  UserInfo: \(ns.userInfo)")

            authError = error.localizedDescription
            return false
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            authError = nil // Clear any lingering errors on sign out
            isReady = false
            Task { await ensureSignedIn() } // No anonymous sign-in; just mark ready again
        } catch {
            authError = error.localizedDescription
        }
    }
}
