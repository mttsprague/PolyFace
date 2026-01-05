//
//  BookView.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import SwiftUI
import StripePaymentSheet
import FirebaseAuth

struct BookView: View {
    @ObservedObject var trainersService: TrainersService
    @ObservedObject var scheduleService: ScheduleService
    @ObservedObject var packagesService: PackagesService
    @ObservedObject var usersService: UsersService
    @StateObject private var bookingManager = BookingManager()
    @StateObject private var classesService = ClassesService()
    
    @Binding var initialMode: Int

    @State private var mode: Mode = .lessons
    @State private var selectedTrainer: Trainer?
    @State private var monthStart: Date = Date().startOfMonth()
    @State private var selectedDate: Date = Date()
    @State private var selectedSlot: AvailabilitySlot?
    @State private var bookingInFlight = false
    @State private var bookingAlert: BookingAlert?
    @State private var selectedClass: GroupClass?
    @State private var showingClassRegistration = false
    @State private var selectedPackage: LessonPackage?

    enum Mode: String, CaseIterable { case lessons = "Lessons", classes = "Classes" }

    // Jeff-first ordering for the menu
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
    
    // Get available lesson packages (excluding class passes)
    private var availableLessonPackages: [LessonPackage] {
        let now = Date()
        let filtered = packagesService.packages.filter { pkg -> Bool in
            let isNotClassPass = pkg.packageType != "class_pass"
            let hasRemaining = pkg.lessonsRemaining > 0
            let notExpired = pkg.expirationDate >= now
            return isNotClassPass && hasRemaining && notExpired
        }
        let sorted = filtered.sorted { (a, b) -> Bool in
            return a.expirationDate < b.expirationDate
        }
        return sorted
    }

    var body: some View {
        mainContent
            .navigationViewStyle(.stack)
            .task {
                await loadInitialData()
            }
            .onAppear {
                setupInitialMode()
            }
            .onChangeCompat(of: initialMode) { _, newValue in
                mode = newValue == 1 ? .classes : .lessons
            }
            .onChangeCompat(of: selectedTrainer?.id) { _, _ in
                Task {
                    await loadMonthIfPossible()
                    await loadDayIfPossible()
                }
            }
            .onChangeCompat(of: packagesService.packages) { _, _ in
                updateSelectedPackage()
            }
    }
    
    private var mainContent: some View {
        NavigationView {
            contentView
                .background(Color.platformGroupedBackground.ignoresSafeArea())
                .navigationTitle("Book a Session")
                .navigationBarTitleDisplayMode(.large)
                .alert(item: $bookingAlert) { alert in
                    Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
                }
                .sheet(item: $selectedClass) { classItem in
                    classRegistrationSheet(for: classItem)
                }
        }
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                modePicker
                
                // Show lessons or classes based on mode
                if mode == .lessons {
                    lessonsContent
                } else {
                    classesContent
                }
            }
            .padding(.vertical, Spacing.lg)
        }
    }
    
    private var modePicker: some View {
        Picker("Mode", selection: $mode) {
            Text("Lessons").tag(Mode.lessons)
            Text("Classes").tag(Mode.classes)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Spacing.lg)
        .onChangeCompat(of: mode) { _, newMode in
            if newMode == .classes {
                Task { await classesService.loadOpenClasses() }
            }
        }
    }
    
    private func classRegistrationSheet(for classItem: GroupClass) -> some View {
        ClassRegistrationSheet(
            classItem: classItem,
            classesService: classesService,
            usersService: usersService,
            packagesService: packagesService,
            onRegistered: {
                bookingAlert = BookingAlert(title: "Registered!", message: "You're registered for \(classItem.title)")
                Task { await classesService.loadOpenClasses() }
            }
        )
    }
    
    private func loadInitialData() async {
        if trainersService.trainers.isEmpty {
            await trainersService.loadAll()
        }
        // Auto-select Jeff (or first trainer) once trainers are available
        if selectedTrainer == nil {
            if let jeff = trainersService.trainers.first(where: { isJeff($0) }) {
                selectedTrainer = jeff
            } else {
                selectedTrainer = trainersService.trainers.first
            }
            // After selecting default trainer, load availability
            await loadMonthIfPossible()
            await loadDayIfPossible()
        }
        await packagesService.loadMyPackages()
    }
    
    private func setupInitialMode() {
        // Sync mode with initialMode binding
        mode = initialMode == 1 ? .classes : .lessons
    }
    
    private func updateSelectedPackage() {
        if availableLessonPackages.count == 1 {
            selectedPackage = availableLessonPackages.first
        } else if let selected = selectedPackage, !availableLessonPackages.contains(where: { $0.id == selected.id }) {
            // Reset if selected package is no longer available
            selectedPackage = nil
        }
    }
    
    // MARK: - Lessons Content
    
    private var lessonsContent: some View {
        Group {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Select Trainer")
                    .font(.headingMedium)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, Spacing.lg)

                CardView(padding: Spacing.md) {
                    Menu {
                        ForEach(trainersOrdered, id: \.id) { trainer in
                            Button {
                                selectedTrainer = trainer
                                selectedSlot = nil
                                Task {
                                    await loadMonthIfPossible()
                                    await loadDayIfPossible()
                                }
                            } label: {
                                HStack(spacing: Spacing.sm) {
                                    TrainerAvatarView(trainer: trainer, size: 28)
                                    Text(trainer.name ?? "Unnamed")
                                        .font(.bodyMedium)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: Spacing.md) {
                            TrainerAvatarView(trainer: selectedTrainer, size: 48)

                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text(selectedTrainer?.name ?? "")
                                    .font(.headingSmall)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Professional Trainer")
                                    .font(.bodySmall)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppTheme.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Choose Date")
                    .font(.headingMedium)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, Spacing.lg)

                MonthCalendarView(monthStart: $monthStart,
                                  selectedDate: $selectedDate,
                                  availabilityByDay: scheduleService.monthAvailability) { _ in
                    Task {
                        selectedSlot = nil
                        await loadMonthIfPossible()
                        await loadDayIfPossible()
                    }
                }
                .onChangeCompat(of: selectedDate) { _, _ in
                    selectedSlot = nil
                    Task { await loadDayIfPossible() }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Available Times")
                    .font(.headingMedium)
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.horizontal, Spacing.lg)

                VStack(spacing: Spacing.sm) {
                    if scheduleService.isLoadingDay {
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(AppTheme.primary)
                            Spacer()
                        }
                        .padding(Spacing.xl)
                    } else if scheduleService.daySlots.isEmpty {
                        EmptyStateView(
                            icon: "calendar.badge.clock",
                            title: "No Slots Available",
                            message: "There are no available time slots for this date. Try selecting a different date."
                        )
                        .padding(.horizontal, Spacing.lg)
                    } else {
                        ForEach(scheduleService.daySlots, id: \.id) { slot in
                            let isSelected = selectedSlot?.id == slot.id
                            let isBookable = canBookSlot(slot)
                            Button {
                                if isBookable {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedSlot = slot
                                    }
                                }
                            } label: {
                                HStack(spacing: Spacing.md) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                                            .fill(isSelected ? AppTheme.primary.opacity(0.15) : AppTheme.primary.opacity(0.08))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: isBookable ? "clock" : "clock.badge.exclamationmark")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(isBookable ? (isSelected ? AppTheme.primary : AppTheme.textSecondary) : AppTheme.textTertiary)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                                        Text(slot.startTime.formatted(date: .omitted, time: .shortened))
                                            .font(.headingSmall)
                                            .foregroundStyle(isBookable ? AppTheme.textPrimary : AppTheme.textTertiary)
                                        if isBookable {
                                            Text("\(Int((slot.endTime.timeIntervalSince(slot.startTime)) / 60)) min session")
                                                .font(.bodySmall)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        } else {
                                            Text("Too close to start time")
                                                .font(.bodySmall)
                                                .foregroundStyle(AppTheme.textTertiary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    ZStack {
                                        Circle()
                                            .stroke(isSelected ? AppTheme.primary : AppTheme.textTertiary, lineWidth: 2)
                                            .frame(width: 24, height: 24)
                                        if isSelected {
                                            Circle()
                                                .fill(AppTheme.primary)
                                                .frame(width: 12, height: 12)
                                        }
                                    }
                                }
                                .padding(Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                        .fill(Color.platformBackground)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.md, style: .continuous)
                                                .stroke(isSelected ? AppTheme.primary.opacity(0.3) : Color.clear, lineWidth: 2)
                                        )
                                )
                                .lightShadow()
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, Spacing.lg)
                        }
                    }
                }
            }
            
            // Package selection (only show if user has multiple available passes)
            if availableLessonPackages.count > 1 {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Select Pass to Use")
                        .font(.headingMedium)
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, Spacing.lg)

                    CardView(padding: Spacing.md) {
                        Menu {
                            ForEach(availableLessonPackages) { package in
                                Button {
                                    selectedPackage = package
                                } label: {
                                    HStack(spacing: Spacing.sm) {
                                        Text(formatPackageName(package))
                                            .font(.bodyMedium)
                                        Text("(\(package.lessonsRemaining) left)")
                                            .font(.bodySmall)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: Spacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                                        .fill(AppTheme.primary.opacity(0.08))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "ticket")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }
                                
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text(selectedPackage != nil ? formatPackageName(selectedPackage!) : "Choose a pass")
                                        .font(.headingSmall)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(selectedPackage != nil ? "\(selectedPackage!.lessonsRemaining) lessons remaining" : "Select which pass to use")
                                        .font(.bodySmall)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }

            Button {
                if !packagesService.hasAvailableLessons {
                    bookingAlert = .init(
                        title: "No Available Passes",
                        message: "Please purchase lesson passes to continue booking. Visit the Profile tab to buy lessons."
                    )
                } else {
                    Task { await performBooking() }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    if bookingInFlight {
                        ProgressView()
                            .tint(.white)
                    } else if !packagesService.hasAvailableLessons {
                        Image(systemName: "cart.badge.plus")
                    }
                    Text(bookButtonText)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(bookingInFlight || selectedTrainer == nil || selectedSlot == nil || (availableLessonPackages.count > 1 && selectedPackage == nil))
            .opacity((selectedTrainer != nil && selectedSlot != nil && (availableLessonPackages.count <= 1 || selectedPackage != nil)) ? 1.0 : 0.5)
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
        }
    }
    
    // MARK: - Classes Content
    
    private var classesContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Available Classes")
                .font(.headingMedium)
                .foregroundStyle(AppTheme.textPrimary)
            .padding(.horizontal, Spacing.lg)
            
            if classesService.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.primary)
                    Spacer()
                }
                .padding(Spacing.xl)
            } else if classesService.classes.isEmpty {
                EmptyStateView(
                    icon: "figure.volleyball",
                    title: "No Classes Available",
                    message: "Check back soon for upcoming group classes!"
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(classesService.classes) { classItem in
                        ClassCard(
                            classItem: classItem,
                            onTap: {
                                selectedClass = classItem
                            },
                            classesService: classesService
                        )
                        .padding(.horizontal, Spacing.lg)
                    }
                }
            }
        }
    }

    private func isJeff(_ trainer: Trainer) -> Bool {
        (trainer.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare("Jeff Schmitz") == .orderedSame
    }
    
    private func formatPackageName(_ package: LessonPackage) -> String {
        switch package.packageType {
        case "private":
            return "Private Lesson Pass"
        case "2_athlete":
            return "2-Athlete Pass"
        case "3_athlete":
            return "3-Athlete Pass"
        case "class_pass":
            return "Class Pass"
        default:
            return "\(package.totalLessons)-Lesson Pass"
        }
    }

    private var isBookEnabled: Bool {
        guard mode == .lessons,
              selectedTrainer?.id != nil,
              selectedSlot?.id != nil else { return false }
        return packagesService.hasAvailableLessons
    }
    
    private func canBookSlot(_ slot: AvailabilitySlot) -> Bool {
        let now = Date()
        let fiveHoursFromNow = now.addingTimeInterval(5 * 60 * 60)
        return slot.startTime > fiveHoursFromNow
    }
    
    private var bookButtonText: String {
        if mode == .classes {
            return "Confirm Booking"
        }
        if !packagesService.hasAvailableLessons {
            return "Purchase Passes to Continue"
        }
        return bookingInFlight ? "Booking..." : "Confirm Booking"
    }

    private func loadDayIfPossible() async {
        guard let trainerId = selectedTrainer?.id else { return }
        await scheduleService.loadOpenSlots(for: trainerId, on: selectedDate)
    }

    private func loadMonthIfPossible() async {
        guard let trainerId = selectedTrainer?.id else { return }
        await scheduleService.loadMonthAvailability(for: trainerId, monthStart: monthStart)
    }

    private func performBooking() async {
        guard let trainerId = selectedTrainer?.id,
              let slotId = selectedSlot?.id,
              let slot = selectedSlot else { return }
        
        // Check if slot is within 5 hours
        if !canBookSlot(slot) {
            bookingAlert = .init(
                title: "Booking Not Available",
                message: "Lessons cannot be booked within 5 hours of the start time. Please contact Jeff Schmitz for assistance."
            )
            return
        }
        
        // If user has multiple passes, ensure they've selected one
        if availableLessonPackages.count > 1 && selectedPackage == nil {
            bookingAlert = .init(
                title: "Select a Pass",
                message: "Please select which pass you'd like to use for this booking."
            )
            return
        }
        
        bookingInFlight = true
        defer { bookingInFlight = false }
        do {
            // Use selected package if available, otherwise pass empty string for auto-selection
            let packageId = selectedPackage?.id ?? ""
            _ = try await bookingManager.bookLesson(trainerId: trainerId, slotId: slotId, lessonPackageId: packageId)
            
            // Create success message with trainer name
            let trainerName = selectedTrainer?.name ?? "your trainer"
            bookingAlert = .init(
                title: "Booking Confirmed! 🎉",
                message: "Your lesson with \(trainerName) has been successfully booked. See you soon!"
            )
            
            // Refresh data after server writes complete
            await packagesService.loadMyPackages()
            await loadDayIfPossible()
            await loadMonthIfPossible()
            selectedSlot = nil
        } catch {
            bookingAlert = .init(
                title: "Booking Failed",
                message: "We couldn't complete your booking. \(error.localizedDescription)"
            )
        }
    }

    private struct BookingAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }
}

private extension Date {
    func startOfMonth() -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self))!
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
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.primary.opacity(0.8), AppTheme.primaryLight.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: size * 0.6))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Class Card

private struct ClassCard: View {
    let classItem: GroupClass
    let onTap: () -> Void
    @ObservedObject var classesService: ClassesService
    @State private var isRegistered = false
    
    var body: some View {
        Button(action: onTap) {
            CardView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            HStack {
                                Text(classItem.title)
                                    .font(.headingMedium)
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                if isRegistered {
                                    BadgeView(text: "Registered", color: AppTheme.success)
                                }
                            }
                            
                            Text(classItem.description)
                                .font(.bodyMedium)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        if isRegistered {
                            // Don't show capacity if already registered
                            EmptyView()
                        } else if classItem.isFull {
                            BadgeView(text: "Full", color: AppTheme.error)
                        } else {
                            BadgeView(text: "\(classItem.spotsRemaining) spots", color: AppTheme.success)
                        }
                    }
                    
                    Divider()
                    
                    HStack(spacing: Spacing.lg) {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "calendar")
                                .font(.bodySmall)
                            Text(classItem.startTime.formatted(date: .abbreviated, time: .omitted))
                                .font(.bodyMedium)
                        }
                        
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "clock")
                                .font(.bodySmall)
                            Text(classItem.startTime.formatted(date: .omitted, time: .shortened))
                                .font(.bodyMedium)
                        }
                        
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "mappin.circle")
                                .font(.bodySmall)
                            Text(classItem.location)
                                .font(.bodyMedium)
                        }
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            if let id = classItem.id {
                isRegistered = await classesService.isRegistered(for: id)
            } else {
                isRegistered = false
            }
        }
    }
}

// MARK: - Class Registration Sheet

private struct ClassRegistrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let classItem: GroupClass
    @ObservedObject var classesService: ClassesService
    @ObservedObject var usersService: UsersService
    @ObservedObject var packagesService: PackagesService
    let onRegistered: () -> Void
    
    @State private var isRegistering = false
    @State private var isAlreadyRegistered = false
    @State private var registrationSuccessful = false
    @State private var errorMessage: String?
    
    // Find available class pass
    private var availableClassPass: LessonPackage? {
        packagesService.packages.first { pkg in
            pkg.packageType == "class_pass" &&
            pkg.lessonsRemaining > 0 &&
            pkg.expirationDate >= Date()
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(classItem.title)
                            .font(.displaySmall)
                            .foregroundStyle(AppTheme.primary)
                        
                        Text(classItem.description)
                            .font(.bodyLarge)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    CardView {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: "calendar")
                                Text(classItem.startTime.formatted(date: .long, time: .omitted))
                                    .font(.bodyLarge)
                            }
                            
                            Divider()
                            
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: "clock")
                                Text("\(classItem.startTime.formatted(date: .omitted, time: .shortened)) - \(classItem.endTime.formatted(date: .omitted, time: .shortened))")
                                    .font(.bodyLarge)
                            }
                            
                            Divider()
                            
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: "mappin.circle")
                                Text(classItem.location)
                                    .font(.bodyLarge)
                            }
                            
                            Divider()
                            
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: "person.2")
                                Text("\(classItem.currentParticipants) / \(classItem.maxParticipants) registered")
                                    .font(.bodyLarge)
                            }
                            
                            Divider()
                            
                            HStack(spacing: Spacing.xxs) {
                                Image(systemName: "dollarsign.circle")
                                Text("$45.00")
                                    .font(.bodyLarge)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppTheme.primary)
                            }
                        }
                        .foregroundStyle(AppTheme.textPrimary)
                    }
                    
                    if let errorMessage = errorMessage {
                        CardView {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppTheme.error)
                                Text(errorMessage)
                                    .font(.bodySmall)
                                    .foregroundStyle(AppTheme.error)
                            }
                        }
                    }
                    
                    if isAlreadyRegistered {
                        CardView {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.success)
                                Text("You're already registered for this class!")
                                    .font(.bodyMedium)
                                    .foregroundStyle(AppTheme.success)
                            }
                        }
                    } else if registrationSuccessful {
                        CardView {
                            VStack(spacing: Spacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(AppTheme.success)
                                Text("Registration Successful!")
                                    .font(.headingMedium)
                                    .foregroundStyle(AppTheme.success)
                                Text("You're all set for \(classItem.title). We'll see you there!")
                                    .font(.bodyMedium)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                        }
                    } else if !classItem.isFull {
                        if availableClassPass != nil {
                            Button {
                                Task { await registerWithClassPass() }
                            } label: {
                                HStack(spacing: Spacing.sm) {
                                    if isRegistering {
                                        ProgressView().tint(.white)
                                    }
                                    Text(isRegistering ? "Registering..." : "Use Class Pass & Register")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isRegistering || isAlreadyRegistered)
                        } else {
                            CardView {
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    HStack(spacing: Spacing.sm) {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundStyle(AppTheme.warning)
                                        Text("Class Pass Required")
                                            .font(.bodyMedium.bold())
                                            .foregroundStyle(AppTheme.warning)
                                    }
                                    Text("You need a class pass to register. Purchase one from the Profile tab to get started.")
                                        .font(.bodySmall)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                        }
                    } else {
                        CardView {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(AppTheme.error)
                                Text("This class is full")
                                    .font(.bodyMedium)
                                    .foregroundStyle(AppTheme.error)
                            }
                        }
                    }
                }
                .padding(Spacing.lg)
            }
            .background(Color.platformGroupedBackground.ignoresSafeArea())
            .navigationTitle("Class Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            isAlreadyRegistered = await classesService.isRegistered(for: classItem.id ?? "")
            // Load packages to check for class passes
            if packagesService.packages.isEmpty {
                await packagesService.loadMyPackages()
            }
        }
    }
    
    private func registerWithClassPass() async {
        guard let classId = classItem.id else { return }
        guard let classPass = availableClassPass, let passId = classPass.id else {
            errorMessage = "No valid class pass found"
            return
        }
        
        isRegistering = true
        errorMessage = nil
        
        do {
            try await classesService.registerForClassWithPass(
                classId: classId,
                classPassPackageId: passId
            )
            
            // Success! Reload packages and show success state
            await packagesService.loadMyPackages()
            await classesService.loadMyRegisteredClasses()
            
            registrationSuccessful = true
            errorMessage = nil
            
            // Wait a moment for user to see success state
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            onRegistered()
            dismiss()
        } catch {
            errorMessage = "Registration failed: \(error.localizedDescription)"
        }
        
        isRegistering = false
    }
}

// MARK: - iOS 17 onChange compatibility

private extension View {
    @ViewBuilder
    func onChangeCompat<V: Equatable>(
        of value: V,
        perform action: @escaping (_ oldValue: V, _ newValue: V) -> Void
    ) -> some View {
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, visionOS 1.0, *) {
            self.onChange(of: value) { oldValue, newValue in
                action(oldValue, newValue)
            }
        } else {
            // Fallback to the deprecated single-parameter variant without warnings here.
            self.onChange(of: value) { newValue in
                action(newValue, newValue)
            }
        }
    }
}

