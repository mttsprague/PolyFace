//
//  PolyFaceApp.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct PolyFaceApp: App {
    // Keep SwiftData container (we may use it later for caching)
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Configure Firebase
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

