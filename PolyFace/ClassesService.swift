//
//  ClassesService.swift
//  PolyFace
//
//  Created by Assistant on 12/31/25.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ClassesService: ObservableObject {
    @Published private(set) var classes: [GroupClass] = []
    @Published private(set) var upcomingClasses: [GroupClass] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    private let db = Firestore.firestore()
    
    // Load all open classes for registration
    func loadOpenClasses() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let now = Timestamp(date: Date())
            let snapshot = try await db.collection("classes")
                .whereField("isOpenForRegistration", isEqualTo: true)
                .whereField("startTime", isGreaterThan: now)
                .order(by: "startTime")
                .getDocuments()
            
            classes = snapshot.documents.compactMap { doc in
                decodeClass(id: doc.documentID, data: doc.data())
            }
        } catch {
            errorMessage = error.localizedDescription
            classes = []
        }
        
        isLoading = false
    }
    
    // Load next 3 upcoming classes
    func loadUpcomingClasses() async {
        do {
            let now = Timestamp(date: Date())
            let snapshot = try await db.collection("classes")
                .whereField("isOpenForRegistration", isEqualTo: true)
                .whereField("startTime", isGreaterThan: now)
                .order(by: "startTime")
                .limit(to: 3)
                .getDocuments()
            
            upcomingClasses = snapshot.documents.compactMap { doc in
                decodeClass(id: doc.documentID, data: doc.data())
            }
        } catch {
            print("Error loading upcoming classes: \(error)")
            upcomingClasses = []
        }
    }
    
    // Register for a class
    func registerForClass(classId: String, firstName: String, lastName: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ClassesService", code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "Not signed in"])
        }
        
        let classRef = db.collection("classes").document(classId)
        
        try await db.runTransaction { transaction, errorPointer in
            let classDoc: DocumentSnapshot
            do {
                try classDoc = transaction.getDocument(classRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard let data = classDoc.data(),
                  let currentParticipants = data["currentParticipants"] as? Int,
                  let maxParticipants = data["maxParticipants"] as? Int else {
                let error = NSError(domain: "ClassesService", code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: "Invalid class data"])
                errorPointer?.pointee = error
                return nil
            }
            
            if currentParticipants >= maxParticipants {
                let error = NSError(domain: "ClassesService", code: -1,
                                   userInfo: [NSLocalizedDescriptionKey: "Class is full"])
                errorPointer?.pointee = error
                return nil
            }
            
            // Increment participants
            transaction.updateData(["currentParticipants": currentParticipants + 1], forDocument: classRef)
            
            // Add user to participants subcollection with their name
            let participantRef = classRef.collection("participants").document(uid)
            transaction.setData([
                "userId": uid,
                "firstName": firstName,
                "lastName": lastName,
                "registeredAt": Timestamp(date: Date())
            ], forDocument: participantRef)
            
            return nil
        }
    }
    
    // Check if user is registered for a class
    func isRegistered(for classId: String) async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        
        do {
            let doc = try await db.collection("classes")
                .document(classId)
                .collection("participants")
                .document(uid)
                .getDocument()
            
            return doc.exists
        } catch {
            return false
        }
    }
    
    private func decodeClass(id: String, data: [String: Any]) -> GroupClass? {
        guard
            let title = data["title"] as? String,
            let description = data["description"] as? String,
            let startTime = (data["startTime"] as? Timestamp)?.dateValue(),
            let endTime = (data["endTime"] as? Timestamp)?.dateValue(),
            let maxParticipants = data["maxParticipants"] as? Int,
            let currentParticipants = data["currentParticipants"] as? Int,
            let location = data["location"] as? String,
            let isOpenForRegistration = data["isOpenForRegistration"] as? Bool,
            let createdBy = data["createdBy"] as? String,
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        else {
            return nil
        }
        
        return GroupClass(
            id: id,
            title: title,
            description: description,
            startTime: startTime,
            endTime: endTime,
            maxParticipants: maxParticipants,
            currentParticipants: currentParticipants,
            location: location,
            isOpenForRegistration: isOpenForRegistration,
            createdBy: createdBy,
            createdAt: createdAt
        )
    }
}
