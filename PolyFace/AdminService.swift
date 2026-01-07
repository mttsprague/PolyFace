//
//  AdminService.swift
//  PolyFace
//
//  Created by Assistant on 12/31/25.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AdminService: ObservableObject {
    @Published private(set) var isAdmin = false
    @Published private(set) var isLoading = false
    @Published private(set) var allUsers: [SimpleUser] = []
    
    private let db = Firestore.firestore()
    
    // Check if current user is admin
    func checkAdminStatus() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("❌ No current user UID")
            isAdmin = false
            return
        }
        
        print("🔍 Checking admin status for UID: \(uid)")
        isLoading = true
        
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if !doc.exists {
                print("❌ User document does not exist for UID: \(uid)")
                isAdmin = false
            } else {
                let data = doc.data() ?? [:]
                print("📄 User document data: \(data)")
                isAdmin = data["isAdmin"] as? Bool ?? false
                print("✅ isAdmin = \(isAdmin)")
            }
        } catch {
            print("❌ Error checking admin status: \(error)")
            isAdmin = false
        }
        
        isLoading = false
    }
    
    // Create a new class (admin only)
    func createClass(
        title: String,
        description: String,
        startTime: Date,
        endTime: Date,
        maxParticipants: Int,
        location: String,
        trainerId: String,
        trainerName: String
    ) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AdminService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        
        guard isAdmin else {
            throw NSError(domain: "AdminService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        
        let classData: [String: Any] = [
            "title": title,
            "description": description,
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime),
            "maxParticipants": maxParticipants,
            "currentParticipants": 0,
            "location": location,
            "isOpenForRegistration": true,
            "trainerId": trainerId,
            "trainerName": trainerName,
            "createdBy": uid,
            "createdAt": Timestamp(date: Date())
        ]
        
        let classRef = try await db.collection("classes").addDocument(data: classData)
        
        // Fetch all trainers
        let trainersSnapshot = try await db.collection("trainers").getDocuments()
        
        // Create a booking in ALL trainers' schedules to block off the time
        let bookingData: [String: Any] = [
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime),
            "status": "booked",
            "clientId": "CLASS",
            "clientName": title,
            "classId": classRef.documentID,
            "isClassBooking": true,
            "bookedAt": Timestamp(date: Date())
        ]
        
        // Add slot to all trainers' schedules
        for trainerDoc in trainersSnapshot.documents {
            try await db.collection("trainers").document(trainerDoc.documentID)
                .collection("schedules").addDocument(data: bookingData)
        }
    }
    
    // Toggle class registration status
    func toggleClassRegistration(classId: String, isOpen: Bool) async throws {
        guard isAdmin else {
            throw NSError(domain: "AdminService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        
        try await db.collection("classes").document(classId)
            .updateData(["isOpenForRegistration": isOpen])
    }
    
    // Delete a class
    func deleteClass(classId: String) async throws {
        guard isAdmin else {
            throw NSError(domain: "AdminService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        
        // Delete the class document
        try await db.collection("classes").document(classId).delete()
        
        // Remove class bookings from all trainers' schedules
        let trainersSnapshot = try await db.collection("trainers").getDocuments()
        
        for trainerDoc in trainersSnapshot.documents {
            let schedulesQuery = db.collection("trainers").document(trainerDoc.documentID)
                .collection("schedules")
                .whereField("classId", isEqualTo: classId)
                .whereField("isClassBooking", isEqualTo: true)
            
            let schedulesSnapshot = try await schedulesQuery.getDocuments()
            
            for scheduleDoc in schedulesSnapshot.documents {
                try await scheduleDoc.reference.delete()
            }
        }
    }
    
    // Update a class
    func updateClass(
        classId: String,
        title: String,
        description: String,
        startTime: Date,
        endTime: Date,
        maxParticipants: Int,
        location: String,
        trainerId: String,
        trainerName: String
    ) async throws {
        guard isAdmin else {
            throw NSError(domain: "AdminService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        
        // Update the class document
        try await db.collection("classes").document(classId).updateData([
            "title": title,
            "description": description,
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime),
            "maxParticipants": maxParticipants,
            "location": location,
            "trainerId": trainerId,
            "trainerName": trainerName
        ])
        
        // Remove old bookings from all trainers' schedules
        let trainersSnapshot = try await db.collection("trainers").getDocuments()
        
        for trainerDoc in trainersSnapshot.documents {
            let schedulesQuery = db.collection("trainers").document(trainerDoc.documentID)
                .collection("schedules")
                .whereField("classId", isEqualTo: classId)
                .whereField("isClassBooking", isEqualTo: true)
            
            let schedulesSnapshot = try await schedulesQuery.getDocuments()
            
            for scheduleDoc in schedulesSnapshot.documents {
                try await scheduleDoc.reference.delete()
            }
        }
        
        // Create new bookings on all trainers' schedules with updated times
        let bookingData: [String: Any] = [
            "clientId": "",
            "startTime": Timestamp(date: startTime),
            "endTime": Timestamp(date: endTime),
            "packageType": "class",
            "classId": classId,
            "isClassBooking": true,
            "bookedAt": Timestamp(date: Date())
        ]
        
        for trainerDoc in trainersSnapshot.documents {
            try await db.collection("trainers").document(trainerDoc.documentID)
                .collection("schedules").addDocument(data: bookingData)
        }
    }
    
    // Load all users (admin only)
    func loadAllUsers() async {
        guard isAdmin else { return }
        
        do {
            let snapshot = try await db.collection("users").getDocuments()
            allUsers = snapshot.documents.compactMap { doc in
                let data = doc.data()
                let firstName = data["firstName"] as? String ?? ""
                let lastName = data["lastName"] as? String ?? ""
                let athleteFirst = data["athleteFirstName"] as? String ?? ""
                let athleteLast = data["athleteLastName"] as? String ?? ""
                
                return SimpleUser(
                    id: doc.documentID,
                    firstName: firstName,
                    lastName: lastName,
                    athleteName: athleteFirst.isEmpty ? "" : "\(athleteFirst) \(athleteLast)".trimmingCharacters(in: .whitespaces)
                )
            }.sorted { $0.lastName < $1.lastName }
        } catch {
            print("Error loading users: \(error)")
            allUsers = []
        }
    }
    
    // Add pass to client (admin only)
    func addPassToClient(clientId: String, passType: String, totalLessons: Int) async throws {
        guard isAdmin else {
            throw NSError(domain: "AdminService", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Unauthorized"])
        }
        
        let now = Date()
        let expirationDate = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now.addingTimeInterval(365 * 24 * 60 * 60)
        
        let passData: [String: Any] = [
            "packageType": passType,
            "totalLessons": totalLessons,
            "lessonsUsed": 0,
            "purchaseDate": Timestamp(date: now),
            "expirationDate": Timestamp(date: expirationDate),
            "transactionId": "ADMIN_ADDED_\(UUID().uuidString)"
        ]
        
        try await db.collection("users")
            .document(clientId)
            .collection("lessonPackages")
            .addDocument(data: passData)
    }
}

// Simple user model for admin dropdown
struct SimpleUser: Identifiable {
    let id: String
    let firstName: String
    let lastName: String
    let athleteName: String
}
