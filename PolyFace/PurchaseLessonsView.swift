// PurchaseLessonsView.swift
import SwiftUI
import StripePaymentSheet
import FirebaseAuth

@MainActor
struct PurchaseLessonsView: View {
    @ObservedObject var packagesService: PackagesService
    @StateObject private var stripeService = StripeService()
    @StateObject private var customerService = StripeCustomerService()

    // Trainers dropdown
    @StateObject private var trainersService = TrainersService()
    @State private var selectedTrainer: Trainer?

    @State private var isPurchasing = false
    @State private var alert: AlertItem?
    @State private var paymentSheet: PaymentSheet?

    // Default expiration policy
    private let expirationMonths = 12

    // Selected package option
    @State private var selected: PackageOption = .single

    // Jeff-first ordering
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

                // Trainer dropdown menu
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

                // Package options
                VStack(spacing: 14) {
                    packageCard(option: .single)
                    packageCard(option: .twoAthlete)
                    packageCard(option: .threeAthlete)
                    packageCard(option: .classPass)
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
                .disabled(isPurchasing || selectedTrainer == nil)
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
        }
        .alert(item: $alert) { a in
            Alert(title: Text(a.title), message: Text(a.message), dismissButton: .default(Text("OK")))
        }
        .paymentSheet(isPresented: Binding(
            get: { paymentSheet != nil },
            set: { if !$0 { paymentSheet = nil } }
        ), paymentSheet: $paymentSheet, onCompletion: handlePaymentCompletion)
    }

    // MARK: - Package Options

    private enum PackageOption: CaseIterable, Equatable {
        case single, twoAthlete, threeAthlete, classPass

        var title: String {
            switch self {
            case .single: return "Single Private Lesson"
            case .twoAthlete: return "2-Athlete Private Lesson"
            case .threeAthlete: return "3-Athlete Private Lesson"
            case .classPass: return "Class Pass"
            }
        }

        var subtitle: String? {
            switch self {
            case .single: return nil
            case .twoAthlete: return "Train with a partner"
            case .threeAthlete: return "Train with two partners"
            case .classPass: return "Register for group classes"
            }
        }

        // Firestore mapping
        var packageType: String {
            switch self {
            case .single: return "single"
            case .twoAthlete: return "two_athlete"
            case .threeAthlete: return "three_athlete"
            case .classPass: return "class_pass"
            }
        }

        var totalLessons: Int {
            switch self {
            case .single: return 1
            case .twoAthlete: return 1
            case .threeAthlete: return 1
            case .classPass: return 1
            }
        }

        // Updated pricing
        var displayPrice: String {
            switch self {
            case .single: return "$80"
            case .twoAthlete: return "$140"
            case .threeAthlete: return "$180"
            case .classPass: return "$45"
            }
        }
        
        // Amount in cents for Stripe
        var amountInCents: Int {
            switch self {
            case .single: return 8000  // $80
            case .twoAthlete: return 14000  // $140
            case .threeAthlete: return 18000  // $180
            case .classPass: return 4500  // $45
            }
        }
    }

    private func packageCard(option: PackageOption) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selected = option }
        } label: {
            HStack(spacing: 12) {
                // Leading icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Brand.primary.opacity(0.15))
                    Image(systemName: "briefcase.fill")
                        .foregroundStyle(Brand.primary)
                        .font(.system(size: 18, weight: .semibold))
                }
                .frame(width: 48, height: 48)

                // Title + savings
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

    // MARK: - Helpers

    private func isJeff(_ trainer: Trainer) -> Bool {
        (trainer.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare("Jeff Schmitz") == .orderedSame
    }

    // MARK: - Purchase flow

    private func purchaseSelectedOption() async {
        guard Auth.auth().currentUser?.uid != nil else {
            alert = .init(title: "Error", message: "You must be signed in to purchase.")
            return
        }
        
        guard let trainerId = selectedTrainer?.id else {
            alert = .init(title: "Error", message: "Please select a trainer.")
            return
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            // Ensure user has a Stripe customer (enables saving cards)
            _ = try await customerService.getOrCreateCustomer()
            
            // Create payment intent
            let clientSecret = try await stripeService.createPaymentIntent(
                packageType: selected.packageType,
                amount: selected.amountInCents,
                trainerId: trainerId
            )
            
            // Configure payment sheet with option to save card
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "Polyface Volleyball Academy"
            configuration.allowsDelayedPaymentMethods = false
            
            // Enable saving payment methods
            configuration.defaultBillingDetails.email = Auth.auth().currentUser?.email
            
            let paymentSheet = PaymentSheet(
                paymentIntentClientSecret: clientSecret,
                configuration: configuration
            )
            
            self.paymentSheet = paymentSheet
        } catch {
            alert = .init(title: "Payment Failed", message: error.localizedDescription)
        }
    }
    
    private func handlePaymentCompletion(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            Task {
                // Payment succeeded - now confirm and create the package
                guard let paymentIntentId = stripeService.lastPaymentIntentId else {
                    alert = .init(title: "Error", message: "Payment succeeded but package creation failed. Please contact support.")
                    return
                }
                
                do {
                    // Call backend to confirm payment and create package
                    try await stripeService.confirmPayment(paymentIntentId: paymentIntentId)
                    
                    // Reload packages to show the new one
                    await packagesService.loadMyPackages()
                } catch {
                    alert = .init(title: "Error", message: "Payment succeeded but package creation failed. Please contact support. \(error.localizedDescription)")
                    return
                }
                
                // Create user-friendly success message based on package type
                let successMessage: String
                switch selected {
                case .single:
                    successMessage = "Your private lesson has been added to your account. You can now book a session!"
                case .twoAthlete:
                    successMessage = "Your 2-athlete lesson has been added to your account. Ready to train with a partner!"
                case .threeAthlete:
                    successMessage = "Your 3-athlete lesson has been added to your account. Ready to train with your group!"
                case .classPass:
                    successMessage = "Your class pass has been added to your account. You can now register for group classes!"
                }
                
                alert = .init(title: "Purchase Successful! 🎉", message: successMessage)
            }
        case .canceled:
            alert = .init(title: "Payment Cancelled", message: "Your payment was cancelled. No charges were made.")
        case .failed(let error):
            alert = .init(title: "Payment Failed", message: "We couldn't process your payment. \(error.localizedDescription)")
        }
    }

    // MARK: - Alert

    private struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
}

// MARK: - Trainer Avatar

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
