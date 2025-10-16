//
//  ProfileView.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//

import SwiftUI
import FirebaseAuth

struct ProfileView: View {
    @EnvironmentObject var auth: AuthManager
    @ObservedObject var usersService: UsersService
    @ObservedObject var packagesService: PackagesService
    @ObservedObject var bookingsService: BookingsService
    @ObservedObject var scheduleService: ScheduleService

    @State private var authMode: AuthMode = .signIn
    enum AuthMode: String, CaseIterable { case signIn = "Sign In", register = "Register" }

    // Consider FirebaseAuth session as "signed in" for UI
    private var isSignedIn: Bool { Auth.auth().currentUser != nil }

    var body: some View {
        NavigationStack {
            Group {
                if isSignedIn {
                    SignedInProfileScreen(usersService: usersService,
                                          packagesService: packagesService,
                                          bookingsService: bookingsService,
                                          scheduleService: scheduleService)
                        .toolbar {
                            #if os(iOS)
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Sign Out") { auth.signOut() }
                            }
                            #else
                            ToolbarItem {
                                Button("Sign Out") { auth.signOut() }
                            }
                            #endif
                        }
                } else {
                    VStack(spacing: 24) {
                        Picker("Mode", selection: $authMode) {
                            Text("Sign In").tag(AuthMode.signIn)
                            Text("Register").tag(AuthMode.register)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        if authMode == .signIn {
                            SignInForm()
                        } else {
                            RegisterForm()
                        }

                        if let error = auth.authError {
                            Text(error).foregroundStyle(.red).font(.footnote).padding(.horizontal)
                        }

                        Spacer(minLength: 20)
                    }
                    .navigationTitle(authMode == .signIn ? "Sign In" : "Register")
                }
            }
            .task {
                if isSignedIn {
                    await usersService.loadCurrentUserIfAvailable()
                    await packagesService.loadMyPackages()
                    await bookingsService.loadMyBookings()
                }
            }
        }
    }
}

// MARK: - Signed-in Profile Screen

private struct SignedInProfileScreen: View {
    @ObservedObject var usersService: UsersService
    @ObservedObject var packagesService: PackagesService
    @ObservedObject var bookingsService: BookingsService
    @ObservedObject var scheduleService: ScheduleService
    @StateObject private var trainersService = TrainersService()

    @State private var tab: Tab = .schedule
    enum Tab: String { case schedule = "SCHEDULE", passes = "PASSES", wallet = "WALLET" }

    // Shared venue/location (matches HomeView)
    private let venueName = "Midtown"
    private let venueCityStateZip = "Chattanooga, TN 37411"

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                tabBar
                content
            }
            .padding(.bottom, 24)
        }
        .background(Color.platformGroupedBackground)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if trainersService.trainers.isEmpty {
                await trainersService.loadAll()
            }
        }
        .refreshable {
            await usersService.loadCurrentUserIfAvailable()
            await packagesService.loadMyPackages()
            await bookingsService.loadMyBookings()
        }
    }

    // Header with curved background, avatar, name, email
    private var header: some View {
        let name = (usersService.currentUser?.displayName.isEmpty == false
                    ? usersService.currentUser!.displayName
                    : (Auth.auth().currentUser?.displayName ?? "Client"))
        let email = usersService.currentUser?.emailAddress ?? Auth.auth().currentUser?.email
        let initials = initialsFrom(name: name, emailFallback: email ?? "")

        return ZStack(alignment: .bottom) {
            // Curved background: place a very large circle well above the top
            GeometryReader { proxy in
                let circleSize = proxy.size.width * 2.2
                // Position the circle's center above the visible area so only the bottom arc shows
                Circle()
                    .fill(Brand.primary)
                    .frame(width: circleSize, height: circleSize)
                    // Center horizontally, push center far above the top so the arc dips down
                    .position(x: proxy.size.width / 2, y: -circleSize * 0.32)
            }
            .frame(height: 180) // visible header height

            // Avatar + name + email
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color.platformBackground)
                        .frame(width: 98, height: 98)
                        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
                    Circle().fill(Color.gray.opacity(0.18))
                        .frame(width: 90, height: 90)
                    Text(initials)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.primary)
                }
                Text(name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.primary)
                if let email {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 12)
        }
        .padding(.bottom, 8)
    }

    // Segmented tab bar (SCHEDULE / PASSES / WALLET)
    private var tabBar: some View {
        HStack(spacing: 24) {
            tabItem(.schedule)
            tabItem(.passes)
            tabItem(.wallet)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private func tabItem(_ t: Tab) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { tab = t }
        } label: {
            VStack(spacing: 6) {
                Text(t.rawValue)
                    .font(.system(size: 14, weight: tab == t ? .bold : .regular))
                    .foregroundStyle(tab == t ? .primary : .secondary)
                Rectangle()
                    .fill(tab == t ? Brand.primary : .clear)
                    .frame(height: 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cornerRadius(1.5)
                    .opacity(tab == t ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // Tab content
    @ViewBuilder
    private var content: some View {
        switch tab {
        case .schedule:
            scheduleTab
        case .passes:
            passesTab
        case .wallet:
            walletTab
        }
    }

    // MARK: SCHEDULE tab

    private var scheduleTab: some View {
        VStack(spacing: 16) {
            // Next Lesson card
            card {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Next Lesson")
                            .font(.title3.bold())
                            .foregroundStyle(Brand.primary)
                        if let next = nextUpcomingBooking() {
                            if let start = next.startTime, let end = next.endTime {
                                Text("\(dateString(start)) • \(timeString(start))–\(timeString(end))")
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 6) {
                                    Image(systemName: "person.fill").foregroundStyle(.secondary)
                                    Text(trainerName(for: next.trainerUID))
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                                    Text("\(venueName) • \(venueCityStateZip)")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text("Your next booked lesson will appear here.")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Your next booked lessons will appear here.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }

            // Moved button below the card, renamed to "View Full Schedule"
            NavigationLink {
                MyUpcomingLessonsView(bookingsService: bookingsService,
                                      trainersService: trainersService,
                                      venueName: venueName,
                                      venueCityStateZip: venueCityStateZip)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                    Text("View Full Schedule")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Brand.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            // Previous lessons card
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Previous")
                        .font(.title3.bold())
                        .foregroundStyle(Brand.primary)
                    let prev = previousBookings()
                    if prev.isEmpty {
                        Text("No previous lessons found.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(prev) { booking in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lesson • \(booking.status.capitalized)")
                                    .font(.headline)
                                if let s = booking.startTime, let e = booking.endTime {
                                    Text("\(dateString(s)) • \(timeString(s))–\(timeString(e))")
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "person.fill").foregroundStyle(.secondary)
                                    Text(trainerName(for: booking.trainerUID))
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                                    Text("\(venueName) • \(venueCityStateZip)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                            if booking.id != prev.last?.id {
                                Divider().opacity(0.2)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: PASSES tab (updated)

    private var passesTab: some View {
        VStack(spacing: 12) {
            if packagesService.isLoading {
                ProgressView().padding()
            } else {
                // Lessons summary card (no inline Buy button)
                card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lessons")
                            .font(.title3.bold())
                            .foregroundStyle(Brand.primary)

                        Text("Passes Remaining")
                            .foregroundStyle(.secondary)

                        Text("\(remainingCredits)")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                }

                // Individual available lessons with expiration date and header
                if !expandedCredits.isEmpty {
                    card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Available Lessons")
                                .font(.title3.bold())
                                .foregroundStyle(Brand.primary)

                            // Header row
                            HStack {
                                Text("Lesson")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Expiration Date")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)

                            ForEach(expandedCredits.indices, id: \.self) { idx in
                                let credit = expandedCredits[idx]
                                HStack {
                                    Text("Lesson")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(dateString(credit.expirationDate))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 6)

                                if idx < expandedCredits.count - 1 {
                                    Divider().opacity(0.15)
                                }
                            }
                        }
                    }
                } else {
                    card {
                        Text("No available lessons.")
                            .foregroundStyle(.secondary)
                    }
                }

                // Bottom Buy button (single purchase entry point)
                NavigationLink {
                    PurchaseLessonsView(packagesService: packagesService)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Buy Lessons")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Brand.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: WALLET tab (placeholder)

    private var walletTab: some View {
        VStack(spacing: 12) {
            card {
                Text("Wallet coming soon.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Helpers

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.platformBackground)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            )
    }

    private func initialsFrom(name: String, emailFallback: String) -> String {
        let parts = name.split(separator: " ").map(String.init)
        let initials: String
        if parts.count >= 2, let f = parts.first?.first, let l = parts.last?.first {
            initials = String([f, l])
        } else if let f = parts.first?.first {
            initials = String(f)
        } else if let first = emailFallback.first {
            initials = String(first)
        } else {
            initials = "?"
        }
        return initials.uppercased()
    }

    private func dateString(_ date: Date?) -> String {
        guard let date else { return "-" }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: date)
    }

    private func timeString(_ date: Date?) -> String {
        guard let date else { return "-" }
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short
        return f.string(from: date)
    }

    private func trainerName(for trainerId: String) -> String {
        trainersService.trainers.first(where: { $0.id == trainerId })?.name ?? "Trainer"
    }

    private func nextUpcomingBooking() -> Booking? {
        let now = Date()
        return bookingsService.myBookings
            .filter { ($0.startTime ?? now) >= now }
            .sorted { ($0.startTime ?? .distantFuture) < ($1.startTime ?? .distantFuture) }
            .first
    }

    private func previousBookings() -> [Booking] {
        let now = Date()
        return bookingsService.myBookings
            .filter { ($0.endTime ?? now) < now }
            .sorted { ($0.startTime ?? .distantPast) > ($1.startTime ?? .distantPast) }
    }

    // MARK: Remaining credits + expanded credit list

    private var remainingCredits: Int {
        packagesService.packages.reduce(into: 0) { sum, pkg in
            guard pkg.expirationDate >= Date() else { return }
            sum += max(0, pkg.lessonsRemaining)
        }
    }

    private struct LessonCredit: Identifiable, Hashable {
        let id = UUID()
        let expirationDate: Date
    }

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
}

// MARK: - Existing Auth Forms

private struct SignInForm: View {
    @EnvironmentObject var auth: AuthManager
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 16) {
            TextField("Email", text: $email)
                #if os(iOS)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                #endif
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.platformSecondaryBackground))

            SecureField("Password", text: $password)
                #if os(iOS)
                .textContentType(.password)
                #endif
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.platformSecondaryBackground))

            Button {
                Task { _ = await auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password) }
            } label: {
                Text("Sign In")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Brand.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(email.isEmpty || password.isEmpty)
            .padding(.top, 8)
            .padding(.horizontal)
        }
        .padding(.horizontal)
    }
}

private struct RegisterForm: View {
    @EnvironmentObject var auth: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var athleteFirstName = ""
    @State private var athleteLastName = ""
    @State private var phoneNumber = ""

    var body: some View {
        VStack(spacing: 16) {
            Group {
                TextField("Email", text: $email)
                    #if os(iOS)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    #endif

                SecureField("Password", text: $password)
                    #if os(iOS)
                    .textContentType(.newPassword)
                    #endif

                SecureField("Confirm Password", text: $confirm)
                    #if os(iOS)
                    .textContentType(.newPassword)
                    #endif
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.platformSecondaryBackground))

            HStack(spacing: 12) {
                TextField("First Name", text: $firstName)
                TextField("Last Name", text: $lastName)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.platformSecondaryBackground))

            HStack(spacing: 12) {
                TextField("Athlete First Name", text: $athleteFirstName)
                TextField("Athlete Last Name", text: $athleteLastName)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.platformSecondaryBackground))

            TextField("Phone Number", text: $phoneNumber)
                #if os(iOS)
                .keyboardType(.phonePad)
                #endif
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.platformSecondaryBackground))

            Button {
                Task {
                    guard !email.isEmpty, !password.isEmpty, password == confirm else { return }
                    _ = await auth.register(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                        password: password,
                        firstName: firstName.isEmpty ? nil : firstName,
                        lastName: lastName.isEmpty ? nil : lastName,
                        athleteFirstName: athleteFirstName.isEmpty ? nil : athleteFirstName,
                        athleteLastName: athleteLastName.isEmpty ? nil : athleteLastName,
                        phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber
                    )
                }
            } label: {
                Text("Create Account")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Brand.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(email.isEmpty || password.isEmpty || password != confirm)
            .padding(.horizontal)
        }
        .padding(.horizontal)
    }
}
