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
        location: String
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
            "createdBy": uid,
            "createdAt": Timestamp(date: Date())
        ]
        
        try await db.collection("classes").addDocument(data: classData)
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
        
        try await db.collection("classes").document(classId).delete()
    }
}
