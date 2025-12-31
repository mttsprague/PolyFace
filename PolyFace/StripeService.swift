//
//  StripeService.swift
//  PolyFace
//
//  Created by Assistant on 12/31/25.
//

import Foundation
import FirebaseAuth
import FirebaseFunctions

@MainActor
final class StripeService: ObservableObject {
    private let functions = Functions.functions()
    
    // Create a payment intent for a lesson package
    func createPaymentIntent(
        packageType: String,
        amount: Int, // Amount in cents (e.g., 5000 = $50.00)
        trainerId: String
    ) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw StripeError.notAuthenticated
        }
        
        let callable = functions.httpsCallable("createPaymentIntent")
        let data: [String: Any] = [
            "packageType": packageType,
            "amount": amount,
            "trainerId": trainerId,
            "userId": userId
        ]
        
        do {
            let result = try await callable.call(data)
            guard let resultData = result.data as? [String: Any],
                  let clientSecret = resultData["clientSecret"] as? String else {
                throw StripeError.invalidResponse
            }
            return clientSecret
        } catch {
            print("Error creating payment intent: \(error)")
            throw StripeError.paymentFailed(error.localizedDescription)
        }
    }
    
    // Confirm payment and create lesson package
    func confirmPayment(paymentIntentId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw StripeError.notAuthenticated
        }
        
        let callable = functions.httpsCallable("confirmPaymentAndCreatePackage")
        let data: [String: Any] = [
            "paymentIntentId": paymentIntentId,
            "userId": userId
        ]
        
        do {
            _ = try await callable.call(data)
        } catch {
            print("Error confirming payment: \(error)")
            throw StripeError.paymentFailed(error.localizedDescription)
        }
    }
    
    enum StripeError: LocalizedError {
        case notAuthenticated
        case invalidResponse
        case paymentFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return "You must be signed in to make a purchase"
            case .invalidResponse:
                return "Invalid response from payment service"
            case .paymentFailed(let message):
                return "Payment failed: \(message)"
            }
        }
    }
}
