//
//  BookingCallError.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//

import Foundation

enum BookingCallError: Error, LocalizedError {
    case notAuthenticated
    case noAvailablePackage
    case invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to book a lesson."
        case .noAvailablePackage:
            return "No valid lesson credits available."
        case .invalidResponse:
            return "Unexpected response from the server."
        case .server(let message):
            return message
        }
    }
}
