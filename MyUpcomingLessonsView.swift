//
//  MyUpcomingLessonsView.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/16/25.
//

import SwiftUI

struct MyUpcomingLessonsView: View {
    @ObservedObject var bookingsService: BookingsService
    @ObservedObject var trainersService: TrainersService
    @StateObject private var classesService = ClassesService()
    @StateObject private var cancellationService = CancellationService()
    @StateObject private var packagesService = PackagesService()

    // Shared venue/location to display
    let venueName: String
    let venueCityStateZip: String
    
    @State private var itemToCancel: ScheduleItem?
    @State private var showCancelAlert = false
    @State private var isCancelling = false
    @State private var cancelError: String?

    private var upcoming: [Booking] {
        let now = Date()
        return bookingsService.myBookings
            .filter { ($0.startTime ?? now) >= now }
            .sorted { ($0.startTime ?? .distantFuture) < ($1.startTime ?? .distantFuture) }
    }
    
    private var upcomingClasses: [GroupClass] {
        let now = Date()
        return classesService.myRegisteredClasses
            .filter { $0.startTime >= now }
            .sorted { $0.startTime < $1.startTime }
    }
    
    private enum ScheduleItem: Identifiable {
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
    
    private var allUpcoming: [ScheduleItem] {
        var items: [ScheduleItem] = []
        items.append(contentsOf: upcoming.map { .lesson($0) })
        items.append(contentsOf: upcomingClasses.map { .classItem($0) })
        return items.sorted { $0.date < $1.date }
    }    
    private func canCancelItem(_ item: ScheduleItem) -> Bool {
        let now = Date()
        let twentyFourHoursFromNow = now.addingTimeInterval(24 * 60 * 60)
        return item.date > twentyFourHoursFromNow
    }
    var body: some View {
        List {
            if (bookingsService.isLoading || classesService.isLoading) && allUpcoming.isEmpty {
                ProgressView()
            } else if allUpcoming.isEmpty {
                Text("No upcoming lessons or classes.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(allUpcoming) { item in
                    let isCancellable = canCancelItem(item)
                    switch item {
                    case .lesson(let booking):
                        LessonRow(booking: booking,
                                  trainerName: trainerName(for: booking.trainerUID),
                                  venueName: venueName,
                                  venueCityStateZip: venueCityStateZip,
                                  isCancellable: isCancellable,
                                  onCancel: {
                                      if isCancellable {
                                          itemToCancel = item
                                          showCancelAlert = true
                                      } else {
                                          cancelError = "Lessons cannot be cancelled within 24 hours of the start time."
                                      }
                                  })
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if isCancellable {
                                    Button(role: .destructive) {
                                        itemToCancel = item
                                        showCancelAlert = true
                                    } label: {
                                        Label("Cancel", systemImage: "xmark.circle")
                                    }
                                }
                            }
                    case .classItem(let classItem):
                        ClassRow(classItem: classItem,
                                 trainerName: trainerName(for: classItem.trainerId),
                                 venueName: venueName,
                                 isCancellable: isCancellable,
                                 onCancel: {
                                      if isCancellable {
                                          itemToCancel = item
                                          showCancelAlert = true
                                      } else {
                                          cancelError = "Classes cannot be cancelled within 24 hours of the start time."
                                      }
                                  })
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if isCancellable {
                                    Button(role: .destructive) {
                                        itemToCancel = item
                                        showCancelAlert = true
                                    } label: {
                                        Label("Cancel", systemImage: "xmark.circle")
                                    }
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("My Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if trainersService.trainers.isEmpty {
                await trainersService.loadAll()
            }
            if bookingsService.myBookings.isEmpty {
                await bookingsService.loadMyBookings()
            }
            if classesService.myRegisteredClasses.isEmpty {
                await classesService.loadMyRegisteredClasses()
            }
        }
        .refreshable {
            await bookingsService.loadMyBookings()
            await classesService.loadMyRegisteredClasses()
        }
        .alert("Cancel Booking", isPresented: $showCancelAlert) {
            Button("Cancel", role: .cancel) {
                itemToCancel = nil
            }
            Button("Confirm", role: .destructive) {
                Task {
                    await handleCancellation()
                }
            }
        } message: {
            Text("Are you sure you want to cancel this booking? Your lesson credit will be returned to your account.")
        }
        .overlay {
            if isCancelling {
                ProgressView("Cancelling...")
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .alert("Cancellation Error", isPresented: Binding(
            get: { cancelError != nil },
            set: { if !$0 { cancelError = nil } }
        )) {
            Button("OK", role: .cancel) {
                cancelError = nil
            }
        } message: {
            if let error = cancelError {
                Text(error)
            }
        }
    }

    private func trainerName(for trainerId: String) -> String {
        trainersService.trainers.first(where: { $0.id == trainerId })?.name ?? "Trainer"
    }
    
    private func handleCancellation() async {
        guard let item = itemToCancel else { return }
        
        isCancelling = true
        defer { isCancelling = false }
        
        do {
            switch item {
            case .lesson(let booking):
                guard let bookingId = booking.id else {
                    cancelError = "Invalid booking ID"
                    return
                }
                try await cancellationService.cancelLesson(bookingId: bookingId)
                
            case .classItem(let classItem):
                guard let classId = classItem.id else {
                    cancelError = "Invalid class ID"
                    return
                }
                try await cancellationService.cancelClassRegistration(classId: classId)
            }
            
            // Refresh all data
            await bookingsService.loadMyBookings()
            await classesService.loadMyRegisteredClasses()
            await packagesService.loadMyPackages()
            
            itemToCancel = nil
            
        } catch {
            cancelError = error.localizedDescription
        }
    }
}

private struct LessonRow: View {
    let booking: Booking
    let trainerName: String
    let venueName: String
    let venueCityStateZip: String
    let isCancellable: Bool
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Brand.primary.opacity(0.12))
                Image(systemName: "calendar.badge.clock")
                    .foregroundStyle(Brand.primary)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 6) {
                Text("Private Lesson")
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let s = booking.startTime, let e = booking.endTime {
                    Text("\(s.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) • \(s.formatted(date: .omitted, time: .shortened))–\(e.formatted(date: .omitted, time: .shortened))")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Time to be determined")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "person.fill").foregroundStyle(.secondary)
                    Text(trainerName)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                    Text("\(venueName) • \(venueCityStateZip)")
                        .foregroundStyle(.secondary)
                }

                Text(booking.status.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: isCancellable ? "xmark.circle.fill" : "lock.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isCancellable ? .red : .gray)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.platformBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }
}
private struct ClassRow: View {
    let classItem: GroupClass
    let trainerName: String
    let venueName: String
    let isCancellable: Bool
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Brand.secondary.opacity(0.12))
                Image(systemName: "sportscourt.fill")
                    .foregroundStyle(Brand.secondary)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 6) {
                Text(classItem.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(classItem.startTime.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) • \(classItem.startTime.formatted(date: .omitted, time: .shortened))–\(classItem.endTime.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "person.fill").foregroundStyle(.secondary)
                    Text(trainerName)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                    Text(classItem.location)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            
            Button(action: onCancel) {
                Image(systemName: isCancellable ? "xmark.circle.fill" : "lock.circle.fill")
                    .font(.title2)
                    .foregroundStyle(isCancellable ? .red : .gray)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.platformBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }
}