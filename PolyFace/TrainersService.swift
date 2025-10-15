//
//  TrainersService.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class TrainersService: ObservableObject {
    @Published private(set) var trainers: [Trainer] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let db = Firestore.firestore()

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        do {
            let snap = try await db.collection("trainers").getDocuments()
            trainers = snap.documents.map { doc in
                let data = doc.data()
                return Trainer(
                    id: doc.documentID,
                    name: data["name"] as? String,
                    email: data["email"] as? String,
                    avatarUrl: data["avatarUrl"] as? String,
                    photoURL: data["photoURL"] as? String,
                    imageUrl: data["imageUrl"] as? String,
                    active: data["active"] as? Bool
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            trainers = []
        }
        isLoading = false
    }
}
