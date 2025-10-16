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

    // Shared venue/location to display
    let venueName: String
    let venueCityStateZip: String

    private var upcoming: [Booking] {
        let now = Date()
        return bookingsService.myBookings
            .filter { ($0.startTime ?? now) >= now }
            .sorted { ($0.startTime ?? .distantFuture) < ($1.startTime ?? .distantFuture) }
    }

    var body: some View {
        List {
            if bookingsService.isLoading && bookingsService.myBookings.isEmpty {
                ProgressView()
            } else if upcoming.isEmpty {
                Text("No upcoming lessons.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(upcoming) { booking in
                    LessonRow(booking: booking,
                              trainerName: trainerName(for: booking.trainerUID),
                              venueName: venueName,
                              venueCityStateZip: venueCityStateZip)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
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
        }
        .refreshable {
            await bookingsService.loadMyBookings()
        }
    }

    private func trainerName(for trainerId: String) -> String {
        trainersService.trainers.first(where: { $0.id == trainerId })?.name ?? "Trainer"
    }
}

private struct LessonRow: View {
    let booking: Booking
    let trainerName: String
    let venueName: String
    let venueCityStateZip: String

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
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.platformBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }
}
