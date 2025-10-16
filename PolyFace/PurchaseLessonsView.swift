// PurchaseLessonsView.swift
import SwiftUI
import StoreKit

@MainActor
struct PurchaseLessonsView: View {
    @ObservedObject var packagesService: PackagesService
    @StateObject private var trainersService = TrainersService()
    @StateObject private var purchaseManager = PurchaseManager()

    @State private var selectedTrainer: Trainer?
    @State private var selectedPackage: PackageOption = .one
    @State private var isPurchasing = false
    @State private var alert: AlertItem?

    // Default expiration policy; change if your rules expect a different window
    private let expirationMonths = 12

    enum PackageOption: CaseIterable, Identifiable {
        case one, five, ten
        var id: String { key }
        var key: String {
            switch self { case .one: return "1"; case .five: return "5"; case .ten: return "10" }
        }
        var title: String {
            switch self {
            case .one: return "Private Lesson"
            case .five: return "5 Private Lessons"
            case .ten: return "10 Private Lessons"
            }
        }
        var subtitle: String? {
            switch self {
            case .one: return nil
            case .five: return "Save $25"
            case .ten: return "Save $100"
            }
        }
        var quantity: Int {
            switch self { case .one: return 1; case .five: return 5; case .ten: return 10 }
        }
        var packageType: String {
            switch self {
            case .one: return "single"
            case .five: return "five_pack"
            case .ten: return "ten_pack"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Purchase Private Lessons")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Brand.primary)
                    .padding(.horizontal)

                trainerCard

                Text("Package")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Brand.primary)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    ForEach(PackageOption.allCases) { option in
                        packageRow(option: option)
                            .padding(.horizontal)
                    }
                }

                Button {
                    Task { await purchaseAndRecord() }
                } label: {
                    HStack {
                        if isPurchasing { ProgressView().tint(.white) }
                        Text("Purchase").font(.headline)
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
            if trainersService.trainers.isEmpty { await trainersService.loadAll() }
            if selectedTrainer == nil {
                if let jeff = trainersService.trainers.first(where: { ($0.name ?? "").localizedCaseInsensitiveCompare("Jeff Schmitz") == .orderedSame }) {
                    selectedTrainer = jeff
                } else {
                    selectedTrainer = trainersService.trainers.first
                }
            }
            // Load the single product (used for all options for now)
            await purchaseManager.loadProduct(identifier: "jeff_lesson")
        }
        .alert(item: $alert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
    }

    private var trainerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trainers")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Brand.primary)

            HStack(spacing: 12) {
                TrainerAvatarMini(trainer: selectedTrainer, size: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedTrainer?.name ?? "Select Trainer")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Trainer")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    ForEach(trainersService.trainers.sorted(by: jeffFirst), id: \.self) { trainer in
                        Button {
                            selectedTrainer = trainer
                        } label: {
                            HStack(spacing: 10) {
                                TrainerAvatarMini(trainer: trainer, size: 24)
                                Text(trainer.name ?? "Unnamed")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(Circle().fill(Color.secondary.opacity(0.12)))
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.platformBackground))
        }
        .padding(.horizontal)
    }

    private func packageRow(option: PackageOption) -> some View {
        let basePrice = purchaseManager.product?.displayPrice ?? "$–"
        let priceText: String
        if let product = purchaseManager.product {
            // Multiply for 5/10 purely for display until distinct products exist
            if option.quantity == 1 {
                priceText = product.displayPrice
            } else {
                let num: Decimal = Decimal(option.quantity) * product.price
                let formatter = product.priceFormatStyle
                priceText = formatter.format(num)
            }
        } else {
            priceText = basePrice
        }

        return Button {
            selectedPackage = option
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Brand.primary.opacity(0.12))
                    Image(systemName: "briefcase.fill")
                        .foregroundStyle(Brand.primary)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .foregroundStyle(.primary)
                    if let sub = option.subtitle {
                        Text(sub).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(priceText)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Image(systemName: selectedPackage == option ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedPackage == option ? Brand.primary : .secondary)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.platformBackground))
        }
        .buttonStyle(.plain)
    }

    private func jeffFirst(_ lhs: Trainer, _ rhs: Trainer) -> Bool {
        func isJeff(_ t: Trainer) -> Bool {
            (t.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare("Jeff Schmitz") == .orderedSame
        }
        let lp = isJeff(lhs) ? 0 : 1
        let rp = isJeff(rhs) ? 0 : 1
        if lp != rp { return lp < rp }
        let ln = lhs.name ?? ""
        let rn = rhs.name ?? ""
        return ln.localizedCaseInsensitiveCompare(rn) == .orderedAscending
    }

    private func purchaseAndRecord() async {
        guard purchaseManager.product != nil else {
            alert = .init(title: "Unavailable", message: "The product is not available for purchase right now.")
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            // For now, regardless of selectedPackage, we buy jeff_lesson once.
            let transaction = try await purchaseManager.purchaseLoadedProduct()

            // Build package payload per your rules
            let now = Date()
            let expiration = Calendar.current.date(byAdding: .month, value: expirationMonths, to: now) ?? now
            try await packagesService.createLessonPackage(
                packageType: selectedPackage.packageType,  // "single" | "five_pack" | "ten_pack"
                totalLessons: selectedPackage.quantity,    // 1 | 5 | 10
                purchaseDate: now,
                expirationDate: expiration,
                transactionId: String(transaction.id)
            )

            await packagesService.loadMyPackages()
            alert = .init(title: "Purchased", message: "Your package has been added to your account.")
        } catch {
            alert = .init(title: "Purchase Failed", message: error.localizedDescription)
        }
    }

    private struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
}

// Small avatar view local to this screen
private struct TrainerAvatarMini: View {
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
                        image.resizable().scaledToFill()
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
            Image(systemName: "person.crop.circle.fill").foregroundStyle(Brand.primary)
        }
    }

    private func trainerImageURL(from trainer: Trainer?) -> URL? {
        guard let trainer else { return nil }
        let urlString = trainer.photoURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? trainer.avatarUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? trainer.imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let s = urlString, !s.isEmpty else { return nil }
        return URL(string: s)
    }
}
