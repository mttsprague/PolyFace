//
//  CancellationService.swift
//  PolyFace
//
//  Created by Assistant on 12/31/25.
//

import Foundation
import FirebaseFunctions

@MainActor
final class CancellationService: ObservableObject {
    private let functions = Functions.functions()
    
    func cancelLesson(bookingId: String) async throws {
        let callable = functions.httpsCallable("cancelLesson")
        let data: [String: Any] = ["bookingId": bookingId]
        
        do {
            _ = try await callable.call(data)
        } catch {
            print("Error cancelling lesson: \(error)")
            throw CancellationError.cancellationFailed(error.localizedDescription)
        }
    }
    
    func cancelClassRegistration(classId: String) async throws {
        let callable = functions.httpsCallable("cancelClassRegistration")
        let data: [String: Any] = ["classId": classId]
        
        do {
            _ = try await callable.call(data)
        } catch {
            print("Error cancelling class registration: \(error)")
            throw CancellationError.cancellationFailed(error.localizedDescription)
        }
    }
    
    enum CancellationError: LocalizedError {
        case cancellationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .cancellationFailed(let message):
                return "Cancellation failed: \(message)"
            }
        }
    }
}
