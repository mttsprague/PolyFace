//
//  Trainer.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import Foundation

// /trainers/{trainerId}
struct Trainer: Identifiable, Hashable {
    var id: String?
    let name: String?
    let email: String?
    let avatarUrl: String?
    let photoURL: String?
    let imageUrl: String?
    let active: Bool?
}
