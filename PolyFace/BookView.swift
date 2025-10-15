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
    @State private var selectedPackageId: String?
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
                VStack(alignment: .leading, spacing: 20) {

                    Picker("Mode", selection: $mode) {
                        Text("Lessons").tag(Mode.lessons)
                        Text("Classes (soon)").tag(Mode.classes)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Text("Trainer")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

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
                                // We ensure selectedTrainer is set after load, so no placeholder text needed.
                                Text(selectedTrainer?.name ?? "")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("Trainer").foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.down").foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.platformBackground).shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4))
                        .padding(.horizontal)
                    }

                    Text("Availability")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

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

                    Text("Times")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        if scheduleService.isLoadingDay {
                            ProgressView().padding()
                        } else if scheduleService.daySlots.isEmpty {
                            Text("No availability for this date.")
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                        } else {
                            ForEach(scheduleService.daySlots, id: \.self) { slot in
                                Button { selectedSlot = slot } label: {
                                    HStack {
                                        Text("\(slot.startTime.formatted(date: .omitted, time: .shortened)) – \(slot.endTime.formatted(date: .omitted, time: .shortened))")
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        if selectedSlot?.id == slot.id {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Brand.primary)
                                        }
                                    }
                                    .padding()
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.platformBackground))
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }

                    if !packagesService.packages.isEmpty {
                        Text("Use Package")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        Picker("Select Lesson Package", selection: $selectedPackageId) {
                            Text("Choose a package").tag(nil as String?)
                            ForEach(packagesService.packages) { pkg in
                                let title = "\(pkg.packageType) • \(max(0, pkg.lessonsRemaining)) left"
                                Text(title).tag(pkg.id as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)
                    }

                    Button { Task { await performBooking() } } label: {
                        HStack { if bookingInFlight { ProgressView().tint(.white) }
                            Text("Book Now").font(.headline)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isBookEnabled ? Brand.primary : Color.gray.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .disabled(!isBookEnabled || bookingInFlight)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("Book")
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
        if !packagesService.packages.isEmpty {
            return selectedPackageId != nil
        }
        return false
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
              let pkgId = selectedPackageId else { return }
        bookingInFlight = true
        defer { bookingInFlight = false }
        do {
            _ = try await bookingManager.bookLesson(trainerId: trainerId, slotId: slotId, lessonPackageId: pkgId)
            bookingAlert = .init(title: "Booked!", message: "Your lesson has been booked successfully.")
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
            Circle().fill(Brand.primary.opacity(0.12))
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(Brand.primary)
        }
    }
}

