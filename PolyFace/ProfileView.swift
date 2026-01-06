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
        NavigationView {
            Group {
                if isSignedIn {
                    SignedInProfileScreen(usersService: usersService,
                                          packagesService: packagesService,
                                          bookingsService: bookingsService,
                                          scheduleService: scheduleService)
                        .toolbar {
                            #if os(iOS)
                            ToolbarItem(placement: .navigationBarTrailing) {
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
        .navigationViewStyle(.stack)
    }
}

// MARK: - Signed-in Profile Screen

private struct SignedInProfileScreen: View {
    @ObservedObject var usersService: UsersService
    @ObservedObject var packagesService: PackagesService
    @ObservedObject var bookingsService: BookingsService
    @ObservedObject var scheduleService: ScheduleService
    @StateObject private var trainersService = TrainersService()
    @StateObject private var classesService = ClassesService()
    @StateObject private var customerService = StripeCustomerService()

    @State private var tab: Tab = .schedule
    enum Tab: String { case schedule = "SCHEDULE", passes = "PASSES", wallet = "WALLET" }

    // Shared venue/location (matches HomeView)
    private let venueName = "Oakwood Community Church"
    private let venueCityStateZip = "Chattanooga, TN 37416"

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
            if classesService.myRegisteredClasses.isEmpty {
                await classesService.loadMyRegisteredClasses()
            }
            if customerService.paymentMethods.isEmpty {
                await customerService.loadPaymentMethods()
            }
        }
        .refreshable {
            await usersService.loadCurrentUserIfAvailable()
            await packagesService.loadMyPackages()
            await bookingsService.loadMyBookings()
            await classesService.loadMyRegisteredClasses()
            await customerService.loadPaymentMethods()
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
            // Next Event card (lesson or class)
            card {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Next Event")
                            .font(.title3.bold())
                            .foregroundStyle(Brand.primary)
                        if let nextEvent = nextUpcomingEvent() {
                            switch nextEvent {
                            case .lesson(let booking):
                                if let start = booking.startTime, let end = booking.endTime {
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.fill").foregroundStyle(.secondary)
                                        Text("Lesson")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    Text("\(dateString(start)) • \(timeString(start))–\(timeString(end))")
                                        .foregroundStyle(.secondary)
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
                            case .classItem(let classItem):
                                HStack(spacing: 6) {
                                    Image(systemName: "sportscourt.fill").foregroundStyle(Brand.secondary)
                                    Text("Class")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Brand.secondary)
                                }
                                Text("\(dateString(classItem.startTime)) • \(timeString(classItem.startTime))–\(timeString(classItem.endTime))")
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 6) {
                                    Image(systemName: "person.fill").foregroundStyle(.secondary)
                                    Text(trainerName(for: classItem.trainerId))
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                                    Text(classItem.location)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Text("Your next events will appear here.")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }

            // View Full Schedule button
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

            // All upcoming events
            card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upcoming")
                        .font(.title3.bold())
                        .foregroundStyle(Brand.primary)
                    let upcoming = allUpcomingEvents()
                    if upcoming.isEmpty {
                        Text("No upcoming lessons or classes.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(upcoming.indices, id: \.self) { idx in
                            let event = upcoming[idx]
                            VStack(alignment: .leading, spacing: 4) {
                                switch event {
                                case .lesson(let booking):
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.fill").foregroundStyle(.secondary)
                                        Text("Lesson • \(booking.status.capitalized)")
                                            .font(.headline)
                                    }
                                    if let s = booking.startTime, let e = booking.endTime {
                                        Text("\(dateString(s)) • \(timeString(s))–\(timeString(e))")
                                            .foregroundStyle(.secondary)
                                    }
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.fill").foregroundStyle(.secondary)
                                        Text(trainerName(for: booking.trainerUID))
                                            .foregroundStyle(.secondary)
                                    }
                                case .classItem(let classItem):
                                    HStack(spacing: 6) {
                                        Image(systemName: "sportscourt.fill").foregroundStyle(Brand.secondary)
                                        Text("Class • \(classItem.title)")
                                            .font(.headline)
                                    }
                                    Text("\(dateString(classItem.startTime)) • \(timeString(classItem.startTime))–\(timeString(classItem.endTime))")
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 6) {
                                        Image(systemName: "person.fill").foregroundStyle(.secondary)
                                        Text(trainerName(for: classItem.trainerId))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                                    Text(venueName)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                            if idx < upcoming.count - 1 {
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
                // Private Lesson Passes
                passTypeCard(title: "Private Lesson Passes", count: privatePassesRemaining, icon: "person.fill")
                
                // 2-Athlete Passes
                passTypeCard(title: "2-Athlete Passes", count: twoAthletePassesRemaining, icon: "person.2.fill")
                
                // 3-Athlete Passes
                passTypeCard(title: "3-Athlete Passes", count: threeAthletePassesRemaining, icon: "person.3.fill")
                
                // Class Passes
                passTypeCard(title: "Class Passes", count: classPassesRemaining, icon: "sportscourt.fill")

                // Bottom Buy button
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
    
    private func passTypeCard(title: String, count: Int, icon: String) -> some View {
        return card {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Brand.primary.opacity(0.15))
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Brand.primary)
                }
                .frame(width: 56, height: 56)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(count) remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Brand.primary)
            }
        }
    }

    // MARK: WALLET tab

    private var walletTab: some View {
        VStack(spacing: 12) {
            if customerService.isLoading {
                ProgressView().padding()
            } else if customerService.paymentMethods.isEmpty {
                card {
                    VStack(spacing: 12) {
                        Image(systemName: "creditcard")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No Saved Cards")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Your saved payment methods will appear here after you make a purchase with the 'Save for future use' option.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                ForEach(customerService.paymentMethods) { method in
                    PaymentMethodCard(
                        method: method,
                        onRemove: {
                            Task {
                                do {
                                    try await customerService.removePaymentMethod(method.id)
                                } catch {
                                    // Handle error - could show alert
                                    print("Failed to remove card: \(error)")
                                }
                            }
                        }
                    )
                }
            }
            
            if let error = customerService.errorMessage {
                card {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
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
    
    // MARK: Event helpers
    
    private enum UpcomingEvent: Identifiable {
        case lesson(Booking)
        case classItem(GroupClass)
        
        var id: String {
            switch self {
            case .lesson(let booking): return "lesson-\(booking.id ?? "")"
            case .classItem(let classItem): return "class-\(classItem.id ?? "")"
            }
        }
        
        var date: Date {
            switch self {
            case .lesson(let booking): return booking.startTime ?? .distantFuture
            case .classItem(let classItem): return classItem.startTime
            }
        }
    }
    
    private func nextUpcomingEvent() -> UpcomingEvent? {
        allUpcomingEvents().first
    }
    
    private func allUpcomingEvents() -> [UpcomingEvent] {
        let now = Date()
        var events: [UpcomingEvent] = []
        
        // Add upcoming lessons
        let upcomingLessons = bookingsService.myBookings
            .filter { ($0.startTime ?? now) >= now }
            .map { UpcomingEvent.lesson($0) }
        events.append(contentsOf: upcomingLessons)
        
        // Add all upcoming classes (user must be registered to see them here)
        let upcomingClasses = classesService.myRegisteredClasses
            .filter { $0.startTime >= now }
            .map { UpcomingEvent.classItem($0) }
        events.append(contentsOf: upcomingClasses)
        
        // Sort by date
        return events.sorted { $0.date < $1.date }
    }

    // MARK: Remaining credits + expanded credit list

    private var remainingCredits: Int {
        packagesService.packages.reduce(into: 0) { sum, pkg in
            guard pkg.expirationDate >= Date() else { return }
            sum += max(0, pkg.lessonsRemaining)
        }
    }
    
    private var privatePassesRemaining: Int {
        packagesService.packages.reduce(into: 0) { sum, pkg in
            guard pkg.expirationDate >= Date() else { return }
            guard pkg.packageType == "private" else { return }
            sum += max(0, pkg.lessonsRemaining)
        }
    }
    
    private var twoAthletePassesRemaining: Int {
        packagesService.packages.reduce(into: 0) { sum, pkg in
            guard pkg.expirationDate >= Date() else { return }
            guard pkg.packageType == "2_athlete" else { return }
            sum += max(0, pkg.lessonsRemaining)
        }
    }
    
    private var threeAthletePassesRemaining: Int {
        packagesService.packages.reduce(into: 0) { sum, pkg in
            guard pkg.expirationDate >= Date() else { return }
            guard pkg.packageType == "3_athlete" else { return }
            sum += max(0, pkg.lessonsRemaining)
        }
    }
    
    private var classPassesRemaining: Int {
        packagesService.packages.reduce(into: 0) { sum, pkg in
            guard pkg.expirationDate >= Date() else { return }
            guard pkg.packageType == "class_pass" else { return }
            sum += max(0, pkg.lessonsRemaining)
        }
    }
    
    private var registeredClassesCount: Int {
        let now = Date()
        // Count upcoming classes the user is registered for
        return classesService.myRegisteredClasses.filter { $0.startTime >= now }.count
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

    @State private var showingWaiver = false
    @State private var waiverSignature: WaiverSignature?
    @State private var isRegistering = false
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var athleteFirstName = ""
    @State private var athleteLastName = ""
    @State private var athlete2FirstName = ""
    @State private var athlete2LastName = ""
    @State private var athlete3FirstName = ""
    @State private var athlete3LastName = ""
    @State private var athletePosition = ""
    @State private var athlete2Position = ""
    @State private var athlete3Position = ""
    @State private var notesForCoach = ""
    @State private var phoneNumber = ""
    
    private var passwordsMatch: Bool {
        password == confirm && !password.isEmpty
    }
    
    private var canSubmit: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        passwordsMatch &&
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !athleteFirstName.isEmpty &&
        !athleteLastName.isEmpty &&
        !athletePosition.isEmpty &&
        !phoneNumber.isEmpty &&
        !isRegistering
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "volleyball.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Brand.primary)
                        .padding(.top, 20)
                    
                    Text("Create Your Account")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Text("Join Polyface Volleyball Academy")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
                
                // Account Credentials Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(icon: "lock.shield.fill", title: "Account Credentials")
                    
                    VStack(spacing: 12) {
                        FormField(
                            icon: "envelope.fill",
                            placeholder: "Email Address",
                            text: $email,
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            autocapitalization: .never
                        )
                        
                        FormField(
                            icon: "lock.fill",
                            placeholder: "Password",
                            text: $password,
                            isSecure: true,
                            textContentType: .newPassword
                        )
                        
                        FormField(
                            icon: "lock.fill",
                            placeholder: "Confirm Password",
                            text: $confirm,
                            isSecure: true,
                            textContentType: .newPassword,
                            validationIcon: password.isEmpty ? nil : (passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill"),
                            validationColor: passwordsMatch ? .green : .red
                        )
                    }
                }
                .padding(.horizontal)
                
                // Parent/Guardian Information Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(icon: "person.fill", title: "Parent/Guardian Information")
                    
                    HStack(spacing: 12) {
                        FormField(
                            icon: "person.circle.fill",
                            placeholder: "First Name",
                            text: $firstName,
                            textContentType: .givenName
                        )
                        
                        FormField(
                            icon: "person.circle.fill",
                            placeholder: "Last Name",
                            text: $lastName,
                            textContentType: .familyName
                        )
                    }
                    
                    FormField(
                        icon: "phone.fill",
                        placeholder: "Phone Number",
                        text: $phoneNumber,
                        keyboardType: .phonePad,
                        textContentType: .telephoneNumber
                    )
                }
                .padding(.horizontal)
                
                // Primary Athlete Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(icon: "figure.volleyball", title: "Primary Athlete")
                    
                    HStack(spacing: 12) {
                        FormField(
                            icon: "sportscourt.fill",
                            placeholder: "First Name",
                            text: $athleteFirstName,
                            textContentType: .givenName
                        )
                        
                        FormField(
                            icon: "sportscourt.fill",
                            placeholder: "Last Name",
                            text: $athleteLastName,
                            textContentType: .familyName
                        )
                    }
                    
                    FormField(
                        icon: "star.fill",
                        placeholder: "Position (e.g., Setter, Outside Hitter)",
                        text: $athletePosition
                    )
                }
                .padding(.horizontal)
                
                // Additional Athletes Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(
                        icon: "person.2.fill",
                        title: "Additional Athletes",
                        subtitle: "Optional"
                    )
                    
                    // Athlete 2
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            FormField(
                                icon: "sportscourt",
                                placeholder: "Athlete 2 First Name",
                                text: $athlete2FirstName,
                                textContentType: .givenName
                            )
                            
                            FormField(
                                icon: "sportscourt",
                                placeholder: "Last Name",
                                text: $athlete2LastName,
                                textContentType: .familyName
                            )
                        }
                        
                        if !athlete2FirstName.isEmpty || !athlete2LastName.isEmpty {
                            FormField(
                                icon: "star",
                                placeholder: "Position",
                                text: $athlete2Position
                            )
                        }
                    }
                    
                    // Athlete 3
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            FormField(
                                icon: "sportscourt",
                                placeholder: "Athlete 3 First Name",
                                text: $athlete3FirstName,
                                textContentType: .givenName
                            )
                            
                            FormField(
                                icon: "sportscourt",
                                placeholder: "Last Name",
                                text: $athlete3LastName,
                                textContentType: .familyName
                            )
                        }
                        
                        if !athlete3FirstName.isEmpty || !athlete3LastName.isEmpty {
                            FormField(
                                icon: "star",
                                placeholder: "Position",
                                text: $athlete3Position
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                // Notes Section
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(
                        icon: "note.text",
                        title: "Notes for Coach",
                        subtitle: "Optional"
                    )
                    
                    TextEditor(text: $notesForCoach)
                        .frame(height: 100)
                        .padding(12)
                        .background(Color(UIColor.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            Group {
                                if notesForCoach.isEmpty {
                                    Text("Share any goals, experience level, or special considerations...")
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                .padding(.horizontal)
                
                // Submit Button
                Button {
                    guard canSubmit else { return }
                    showingWaiver = true
                } label: {
                    HStack(spacing: 12) {
                        if isRegistering {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                        }
                        Text(isRegistering ? "Creating Account..." : "Review Waiver & Complete Registration")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: canSubmit ? [Brand.primary, Brand.primary.opacity(0.8)] : [Color.gray, Color.gray.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: canSubmit ? Brand.primary.opacity(0.3) : Color.clear, radius: 8, y: 4)
                }
                .disabled(!canSubmit)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Privacy Note
                Text("By registering, you'll review and sign our liability waiver")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingWaiver) {
            WaiverAgreementView { signature in
                // Waiver signed - now create the account
                waiverSignature = signature
                showingWaiver = false
                
                Task {
                    await registerWithWaiver(signature: signature)
                }
            }
        }
    }
    
    private func registerWithWaiver(signature: WaiverSignature) async {
        isRegistering = true
        defer { isRegistering = false }
        
        // Step 1: Create Firebase Auth account
        let success = await auth.register(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            firstName: firstName.isEmpty ? nil : firstName,
            lastName: lastName.isEmpty ? nil : lastName,
            athleteFirstName: athleteFirstName.isEmpty ? nil : athleteFirstName,
            athleteLastName: athleteLastName.isEmpty ? nil : athleteLastName,
            athlete2FirstName: athlete2FirstName.isEmpty ? nil : athlete2FirstName,
            athlete2LastName: athlete2LastName.isEmpty ? nil : athlete2LastName,
            athlete3FirstName: athlete3FirstName.isEmpty ? nil : athlete3FirstName,
            athlete3LastName: athlete3LastName.isEmpty ? nil : athlete3LastName,
            athletePosition: athletePosition.isEmpty ? nil : athletePosition,
            athlete2Position: athlete2Position.isEmpty ? nil : athlete2Position,
            athlete3Position: athlete3Position.isEmpty ? nil : athlete3Position,
            notesForCoach: notesForCoach.isEmpty ? nil : notesForCoach,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber
        )
        
        guard success, let userId = Auth.auth().currentUser?.uid else {
            print("❌ Registration failed")
            return
        }
        
        // Step 2: Generate and upload waiver PDF
        do {
            guard let pdfData = WaiverPDFGenerator.generateWaiverPDF(signature: signature) else {
                print("❌ Failed to generate waiver PDF")
                return
            }
            
            print("📄 Uploading waiver for user: \(userId)")
            _ = try await DocumentsService.shared.saveWaiverDocument(
                userId: userId,
                pdfData: pdfData,
                signature: signature
            )
            print("✅ Waiver uploaded and saved successfully")
        } catch {
            print("❌ Error saving waiver: \(error.localizedDescription)")
            // Account is created but waiver failed - they can re-sign later if needed
        }
    }
}

// MARK: - Payment Method Card

private struct PaymentMethodCard: View {
    let method: PaymentMethodInfo
    let onRemove: () -> Void
    
    @State private var showingRemoveConfirmation = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Card icon
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(cardColor.opacity(0.15))
                Image(systemName: cardIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(cardColor)
            }
            .frame(width: 56, height: 56)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(method.displayBrand) •••• \(method.last4)")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Expires \(method.expirationDisplay)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                showingRemoveConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundStyle(.red)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.platformBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .alert("Remove Card?", isPresented: $showingRemoveConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("Are you sure you want to remove this payment method?")
        }
    }
    
    private var cardIcon: String {
        switch method.brand.lowercased() {
        case "visa": return "creditcard.fill"
        case "mastercard": return "creditcard.fill"
        case "amex": return "creditcard.fill"
        case "discover": return "creditcard.fill"
        default: return "creditcard"
        }
    }
    
    private var cardColor: Color {
        switch method.brand.lowercased() {
        case "visa": return .blue
        case "mastercard": return .orange
        case "amex": return .green
        case "discover": return .purple
        default: return Brand.primary
        }
    }
}

// MARK: - Registration Form Components

private struct SectionHeader: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Brand.primary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Brand.primary.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
    }
}

private struct FormField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .words
    var validationIcon: String? = nil
    var validationColor: Color? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Brand.primary)
                .frame(width: 20)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(textContentType)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textContentType(textContentType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled(autocapitalization == .never)
            }
            
            if let validationIcon = validationIcon {
                Image(systemName: validationIcon)
                    .foregroundStyle(validationColor ?? .secondary)
                    .font(.body)
            }
        }
        .padding(16)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
