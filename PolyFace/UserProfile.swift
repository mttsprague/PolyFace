import Foundation

// /users/{uid}
struct UserProfile: Identifiable {
    var id: String? // Firebase Auth UID
    var emailAddress: String?
    var firstName: String?
    var lastName: String?
    var athleteFirstName: String?
    var athleteLastName: String?
    var athleteBirthday: String?
    var athlete2FirstName: String?
    var athlete2LastName: String?
    var athlete2Birthday: String?
    var athlete3FirstName: String?
    var athlete3LastName: String?
    var athlete3Birthday: String?
    var athletePosition: String?
    var athlete2Position: String?
    var athlete3Position: String?
    var notesForCoach: String?
    var phoneNumber: String?
    var photoURL: String?
    var active: Bool?
    var createdAt: Date?
    var updatedAt: Date?

    var displayName: String {
        let f = (firstName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let l = (lastName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return [f, l].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
