//
//  BookView.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import SwiftUI

struct BookView: View {
    @ObservedObject var trainersService: TrainersService
    @ObservedObject var scheduleService: ScheduleService
    @ObservedObject var packagesService: PackagesService
    @StateObject private var bookingManager = BookingManager()

    @State private var mode: Mode = .lessons
    @State private var selectedTrainer: Trainer?
    @State private var monthStart: Date = Date().startOfMonth()
    @State private var selectedDate: Date = Date()
    @State private var selectedSlot: AvailabilitySlot?
    @State private var bookingInFlight = false
    @State private var bookingAlert: BookingAlert?

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {

                    Picker("Mode", selection: $mode) {
                        Text("Lessons").tag(Mode.lessons)
                        Text("Classes (soon)").tag(Mode.classes)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Spacing.lg)

                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Select Trainer")
                            .font(.headingMedium)
                            .foregroundStyle(AppTheme.textPrimary)
                            .padding(.horizontal, Spacing.lg)

                        CardView(padding: Spacing.md) {
                            Menu {
                                ForEach(trainersOrdered, id: \.self) { trainer in
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
                        .onChange(of: selectedDate) {
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
                                ForEach(scheduleService.daySlots, id: \.self) { slot in
                                    let isSelected = selectedSlot?.id == slot.id
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedSlot = slot
                                        }
                                    } label: {
                                        HStack(spacing: Spacing.md) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                                                    .fill(isSelected ? AppTheme.primary.opacity(0.15) : AppTheme.primary.opacity(0.08))
                                                    .frame(width: 48, height: 48)
                                                Image(systemName: "clock")
                                                    .font(.system(size: 20, weight: .semibold))
                                                    .foregroundStyle(isSelected ? AppTheme.primary : AppTheme.textSecondary)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                                Text(slot.startTime.formatted(date: .omitted, time: .shortened))
                                                    .font(.headingSmall)
                                                    .foregroundStyle(AppTheme.textPrimary)
                                                Text("\(Int((slot.endTime.timeIntervalSince(slot.startTime)) / 60)) min session")
                                                    .font(.bodySmall)
                                                    .foregroundStyle(AppTheme.textSecondary)
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

                    Button {
                        Task { await performBooking() }
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            if bookingInFlight {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(bookingInFlight ? "Booking..." : "Confirm Booking")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!isBookEnabled || bookingInFlight)
                    .opacity(isBookEnabled ? 1.0 : 0.5)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.md)
                }
                .padding(.vertical, Spacing.lg)
            }
            .background(Color.platformGroupedBackground.ignoresSafeArea())
            .navigationTitle("Book a Session")
            .navigationBarTitleDisplayMode(.large)
            .alert(item: $bookingAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
        .task {
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
        .onChange(of: selectedTrainer) {
            Task {
                await loadMonthIfPossible()
                await loadDayIfPossible()
            }
        }
    }

    private func isJeff(_ trainer: Trainer) -> Bool {
        (trainer.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            .localizedCaseInsensitiveCompare("Jeff Schmitz") == .orderedSame
    }

    private var isBookEnabled: Bool {
        guard mode == .lessons,
              selectedTrainer?.id != nil,
              selectedSlot?.id != nil,
              packagesService.hasAvailableLessons else { return false }
        return true
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
              let slotId = selectedSlot?.id else { return }
        bookingInFlight = true
        defer { bookingInFlight = false }
        do {
            // BookingManager ignores the lessonPackageId argument and chooses automatically.
            _ = try await bookingManager.bookLesson(trainerId: trainerId, slotId: slotId, lessonPackageId: "")
            bookingAlert = .init(title: "Booked!", message: "Your lesson has been booked successfully.")
            // Refresh data after server writes complete
            await packagesService.loadMyPackages()
            await loadDayIfPossible()
            await loadMonthIfPossible()
            selectedSlot = nil
        } catch {
            bookingAlert = .init(title: "Booking Failed", message: error.localizedDescription)
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
