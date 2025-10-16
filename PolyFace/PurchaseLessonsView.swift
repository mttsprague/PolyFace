// PurchaseLessonsView.swift
import SwiftUI
import StoreKit

@MainActor
struct PurchaseLessonsView: View {
    @ObservedObject var packagesService: PackagesService
    @StateObject private var purchaseManager = PurchaseManager()

    // Trainers dropdown (same wiring as BookView)
    @StateObject private var trainersService = TrainersService()
    @State private var selectedTrainer: Trainer?

    @State private var isPurchasing = false
    @State private var alert: AlertItem?

    // Default expiration policy for newly purchased packages
    private let expirationMonths = 12

    // Selected package option (radio-style)
    @State private var selected: PackageOption = .single

    // Jeff-first ordering for the menu (copied from BookView)
    private var trainersOrdered: [Trainer] {
        trainersService.trainers.sorted { lhs, rhs in
            let lhsPriority = isJeff(lhs) ? 0 : 1
            let rhsPriority = isJeff(rhs) ? 0 : 1
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            let ln = lhs.name ?? ""
            let rn = rhs.name ?? ""
            return ln.localizedCaseInsensitiveCompare(rn) == .orderedAscending
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Big page header
                Text("Purchase Private Lessons")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Brand.primary)
                    .padding(.horizontal)

                // Trainers header
                Text("Trainer")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                // Trainer dropdown menu (mirrors BookView)
                Menu {
                    ForEach(trainersOrdered, id: \.self) { trainer in
                        Button {
                            selectedTrainer = trainer
                        } label: {
                            HStack(spacing: 10) {
                                TrainerAvatarView(trainer: trainer, size: 24)
                                Text(trainer.name ?? "Unnamed")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        TrainerAvatarView(trainer: selectedTrainer, size: 36)

                        VStack(alignment: .leading) {
                            Text(selectedTrainer?.name ?? "")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text("Trainer").foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.down").foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.platformBackground)
                            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                    )
                    .padding(.horizontal)
                }

                // Package section header
                Text("Package")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Brand.primary)
                    .padding(.horizontal)

                // Package options (radio cards)
                VStack(spacing: 14) {
                    packageCard(option: .single)
                    packageCard(option: .five)
                    packageCard(option: .ten)
                }
                .padding(.horizontal)

                // Bottom Purchase button
                Button {
                    Task { await purchaseSelectedOption() }
                } label: {
                    HStack {
                        if isPurchasing { ProgressView().tint(.white) }
                        Spacer(minLength: 0)
                        Text("Purchase")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 20)
                    .background(Brand.primary)
                    .clipShape(Capsule())
                }
                .disabled(isPurchasing || purchaseManager.product == nil)
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 12)
            }
            .padding(.top, 12)
        }
        .background(Color.platformGroupedBackground)
        .navigationTitle("Purchase Private Lessons")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Load trainers and default-select Jeff (or first)
            if trainersService.trainers.isEmpty {
                await trainersService.loadAll()
            }
            if selectedTrainer == nil {
                if let jeff = trainersService.trainers.first(where: { isJeff($0) }) {
                    selectedTrainer = jeff
                } else {
                    selectedTrainer = trainersService.trainers.first
                }
            }

            // Load the product used for purchases (all map to this for now)
            await purchaseManager.loadProduct(identifier: "jeff_lesson")
        }
        .alert(item: $alert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
    }

    // MARK: - Package Options

    private enum PackageOption: CaseIterable, Equatable {
        case single, five, ten

        var title: String {
            switch self {
            case .single: return "Private Lesson"
            case .five:   return "5 Private Lessons"
            case .ten:    return "10 Private Lessons"
            }
        }

        var subtitle: String? {
            switch self {
            case .single: return nil
            case .five:   return "Save $25"
            case .ten:    return "Save $100"
            }
        }

        // Firestore mapping
        var packageType: String {
            switch self {
            case .single: return "single"
            case .five:   return "five_pack"
            case .ten:    return "ten_pack"
            }
        }

        var totalLessons: Int {
            switch self {
            case .single: return 1
            case .five:   return 5
            case .ten:    return 10
            }
        }

        // Display prices shown in screenshot (can be swapped to dynamic later)
        var displayPrice: String {
            switch self {
            case .single: return "$90"
            case .five:   return "$425"
            case .ten:    return "$800"
            }
        }
    }

    private func packageCard(option: PackageOption) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selected = option }
        } label: {
            HStack(spacing: 12) {
                // Leading icon in rounded square
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Brand.primary.opacity(0.15))
                    Image(systemName: "briefcase.fill")
                        .foregroundStyle(Brand.primary)
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(width: 48, height: 48)

                // Title + optional savings
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .foregroundStyle(.primary)
                        .font(.headline)
                    if let sub = option.subtitle {
                        Text(sub)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                }

                Spacer()

                // Price
                Text(option.displayPrice)
                    .font(.headline)
                    .foregroundStyle(.primary)

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(Brand.primary, lineWidth: 2)
                        .frame(width: 26, height: 26)
                    if selected == option {
                        Circle()
                            .fill(Brand.primary)
                            .frame(width: 22, height: 22)
                            .overlay(Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.platformBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers (matching BookView behavior)

    private func isJeff(_ trainer: Trainer) -> Bool {
        (trainer.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare("Jeff Schmitz") == .orderedSame
    }

    // MARK: - Purchase flow

    private func purchaseSelectedOption() async {
        guard purchaseManager.product != nil else {
            alert = .init(title: "Unavailable", message: "The product is not available for purchase right now.")
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let transaction = try await purchaseManager.purchaseLoadedProduct()

            let now = Date()
            let expiration = Calendar.current.date(byAdding: .month, value: expirationMonths, to: now) ?? now

            try await packagesService.createLessonPackage(
                packageType: selected.packageType,
                totalLessons: selected.totalLessons,
                purchaseDate: now,
                expirationDate: expiration,
                transactionId: String(transaction.id)
            )

            await packagesService.loadMyPackages()
            alert = .init(title: "Purchased", message: "Your lessons have been added to your account.")
        } catch {
            if let err = error as? PurchaseManager.PurchaseError, err == .userCancelled {
                alert = .init(title: "Purchase Cancelled", message: "No charges were made.")
            } else {
                alert = .init(title: "Purchase Failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Alert

    private struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
}

// MARK: - Trainer Avatar (copied from BookView for consistency)

private func trainerImageURL(from trainer: Trainer?) -> URL? {
    guard let trainer else { return nil }
    let urlString = trainer.photoURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        ?? trainer.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        ?? trainer.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let s = urlString, !s.isEmpty else { return nil }
    return URL(string: s)
}

private struct TrainerAvatarView: View {
    let trainer: Trainer?
    var size: CGFloat = 36

    var body: some View {
        let cornerRadius = size / 2
        Group {
            if let url = trainerImageURL(from: trainer) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.04), radius: 1, x: 0, y: 1)
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(Brand.primary.opacity(0.12))
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(Brand.primary)
        }
    }
}
