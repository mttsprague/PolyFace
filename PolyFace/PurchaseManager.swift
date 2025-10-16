// PurchaseManager.swift
import Foundation
import StoreKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var product: Product?

    func loadProduct(identifier: String) async {
        do {
            let products = try await Product.products(for: [identifier])
            self.product = products.first
        } catch {
            print("PurchaseManager: failed to load product: \(error)")
            self.product = nil
        }
    }

    // Returns the verified Transaction so callers can read transaction.id
    func purchaseLoadedProduct() async throws -> Transaction {
        guard let product else { throw PurchaseError.productUnavailable }
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            return transaction
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            throw PurchaseError.pending
        @unknown default:
            throw PurchaseError.unknown
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }

    enum PurchaseError: LocalizedError {
        case productUnavailable, userCancelled, pending, unverified, unknown
        var errorDescription: String? {
            switch self {
            case .productUnavailable: return "Product is unavailable."
            case .userCancelled: return "Purchase cancelled."
            case .pending: return "Purchase is pending approval."
            case .unverified: return "Transaction could not be verified."
            case .unknown: return "An unknown purchase error occurred."
            }
        }
    }
}
