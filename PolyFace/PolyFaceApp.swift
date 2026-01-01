//
//  PolyFaceApp.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI
import FirebaseCore
import StripePaymentSheet

@main
struct PolyFaceApp: App {

    init() {
        // Configure Firebase
        FirebaseApp.configure()

        // Configure Stripe
        StripeAPI.defaultPublishableKey = StripeConfig.publishableKey
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
    }
}
