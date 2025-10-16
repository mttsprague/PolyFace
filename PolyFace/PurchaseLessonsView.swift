// PurchaseLessonsView.swift
import SwiftUI
import StoreKit

@MainActor
struct PurchaseLessonsView: View {
    @ObservedObject var packagesService: PackagesService
    @StateObject private var purchaseManager = PurchaseManager()

    @State private var isPurchasing = false
    @State private var alert: AlertItem?

    // Default expiration policy for newly purchased single lessons
    private let expirationMonths = 12

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Lessons")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Brand.primary)
                    .padding(.horizontal)

                // Lessons summary card
                lessonsCard
                    .padding(.horizontal)

                // Individual credits list
                if !expandedCredits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Available Lessons")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Brand.primary)
                            .padding(.horizontal)

                        VStack(spacing: 8) {
                            ForEach(expandedCredits.indices, id: \.self) { idx in
                                let credit = expandedCredits[idx]
                                HStack {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Brand.primary.opacity(0.12))
                                            Image(systemName: "graduationcap.fill")
                                                .foregroundStyle(Brand.primary)
                                        }
                                        .frame(width: 36, height: 36)

                                        Text("Lesson")
                                            .foregroundStyle(.primary)
                                    }

                                    Spacer()

                                    Text(dateString(credit.expirationDate))
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.platformBackground))
                                .padding(.horizontal)
                            }
                        }
                    }
                } else {
                    // Empty state when no credits are available
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No available lessons.")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }

                // Buy button at bottom with cart icon
                Button {
                    Task { await purchaseAndRecord() }
                } label: {
                    HStack(spacing: 10) {
                        if isPurchasing { ProgressView().tint(.white) }
                        Image(systemName: "cart.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Buy Lessons").font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Brand.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .disabled(isPurchasing || purchaseManager.product == nil)
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .padding(.vertical, 12)
        }
        .navigationTitle("Purchase Private Lessons")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.platformGroupedBackground)
        .task {
            if packagesService.packages.isEmpty {
                await packagesService.loadMyPackages()
            }
            // Load the single product (used for purchases)
            await purchaseManager.loadProduct(identifier: "jeff_lesson")
        }
        .alert(item: $alert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Lessons Summary

    private var lessonsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Lessons")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Brand.primary)
                Spacer()
            }

            Text("Passes Remaining")
                .foregroundStyle(.secondary)

            Text("\(remainingCredits)")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.platformBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }

    // MARK: - Data shaping

    private struct LessonCredit: Identifiable, Hashable {
        let id = UUID()
        let expirationDate: Date
    }

    // Sum of remaining (non-expired) lessons across all packages
    private var remainingCredits: Int {
        packagesService.packages.reduce(into: 0) { sum, pkg in
            guard pkg.expirationDate >= Date() else { return }
            sum += max(0, pkg.lessonsRemaining)
        }
    }

    // Expand each package's remaining credits into individual "credit" rows
    private var expandedCredits: [LessonCredit] {
        var credits: [LessonCredit] = []
        for pkg in packagesService.packages where pkg.expirationDate >= Date() {
            let remaining = max(0, pkg.lessonsRemaining)
            if remaining > 0 {
                credits.append(contentsOf: Array(repeating: LessonCredit(expirationDate: pkg.expirationDate), count: remaining))
            }
        }
        return credits
    }

    // MARK: - Purchase flow

    private func purchaseAndRecord() async {
        guard purchaseManager.product != nil else {
            alert = .init(title: "Unavailable", message: "The product is not available for purchase right now.")
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let transaction = try await purchaseManager.purchaseLoadedProduct()

            // Create a single-lesson package per purchase
            let now = Date()
            let expiration = Calendar.current.date(byAdding: .month, value: expirationMonths, to: now) ?? now
            try await packagesService.createLessonPackage(
                packageType: "single",
                totalLessons: 1,
                purchaseDate: now,
                expirationDate: expiration,
                transactionId: String(transaction.id)
            )

            await packagesService.loadMyPackages()
            alert = .init(title: "Purchased", message: "Your lesson has been added to your account.")
        } catch {
            alert = .init(title: "Purchase Failed", message: error.localizedDescription)
        }
    }

    // MARK: - Helpers

    private func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    private struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
}
