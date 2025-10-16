//
//  HomeView.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//

import SwiftUI
import MapKit
import FirebaseAuth

struct HomeView: View {
    @ObservedObject var usersService: UsersService
    @ObservedObject var scheduleService: ScheduleService
    @Environment(\.openURL) private var openURL

    private let venueName = "Midtown"
    private let venueAddressLine = "104 North Tuxedo Avenue"
    private let venueCityStateZip = "Chattanooga, TN 37411"

    private var isAuthenticated: Bool {
        Auth.auth().currentUser != nil
    }

    // Static class previews for the Home screen (not tied to user bookings)
    private var comingUpClasses: [ClassPreview] {
        [
            ClassPreview(
                title: "Beginner Skills Class",
                start: date(year: 2025, month: 9, day: 23, hour: 17, minute: 0),
                end:   date(year: 2025, month: 9, day: 23, hour: 18, minute: 30)
            ),
            ClassPreview(
                title: "Serving & Passing Class",
                start: date(year: 2025, month: 9, day: 25, hour: 18, minute: 0),
                end:   date(year: 2025, month: 9, day: 25, hour: 19, minute: 30)
            ),
            ClassPreview(
                title: "Hitting & Blocking Class",
                start: date(year: 2025, month: 9, day: 27, hour: 10, minute: 0),
                end:   date(year: 2025, month: 9, day: 27, hour: 11, minute: 30)
            )
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome \(usersService.currentUser?.displayName ?? "")")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Brand.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("PolyFace Volleyball Academy")
                        .font(.title2.bold())
                        .foregroundStyle(Brand.primary)

                    Button {
                        openInMaps(address: "\(venueAddressLine), \(venueCityStateZip)")
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Brand.primary.opacity(0.12))
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundStyle(Brand.primary)
                            }
                            .frame(width: 56, height: 56)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(venueName)
                                    .font(.headline)
                                    .foregroundStyle(Brand.primary)
                                Text(venueAddressLine)
                                    .foregroundStyle(.secondary)
                                Text(venueCityStateZip)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            ZStack {
                                Circle()
                                    .fill(Brand.primary.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Brand.primary)
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.platformBackground)
                                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(.plain)

                    // Coming Up (static previews, not user-linked)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Coming Up")
                            .font(.title3.bold())
                            .foregroundStyle(Brand.primary)

                        VStack(spacing: 12) {
                            ForEach(comingUpClasses) { item in
                                ClassPreviewRow(item: item)
                            }
                        }
                    }

                    // Always show this; it will point to the future Classes schedule.
                    NavigationLink {
                        ClassesSchedulePlaceholder()
                    } label: {
                        Text("View Full Schedule")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Brand.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: Brand.primary.opacity(0.35), radius: 8, x: 0, y: 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.platformGroupedBackground)
            .navigationTitle("")
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
        }
        .task {
            // Keep user info fresh if signed in; do not load schedule here.
            if isAuthenticated {
                await usersService.loadCurrentUserIfAvailable()
            }
        }
    }

    private func openInMaps(address: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address
        let search = MKLocalSearch(request: request)
        Task {
            let response = try? await search.start()
            if let mapItem = response?.mapItems.first {
                mapItem.openInMaps(launchOptions: [
                    MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                ])
            } else {
                let query = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "http://maps.apple.com/?q=\(query)") {
                    openURL(url)
                }
            }
        }
    }

    // Build a concrete Date from components in the local calendar/timezone.
    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return Calendar.current.date(from: comps) ?? Date()
    }
}

// MARK: - Class Preview Models/Views

private struct ClassPreview: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let start: Date
    let end: Date
}

private struct ClassPreviewRow: View {
    let item: ClassPreview

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Brand.primary.opacity(0.12))
                Image(systemName: "calendar")
                    .foregroundStyle(Brand.primary)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(item.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) • \(item.start.formatted(date: .omitted, time: .shortened))–\(item.end.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                    Text("TBD").foregroundStyle(.secondary)
                }
                .font(.subheadline)
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

// MARK: - Placeholder destination for future Classes schedule

private struct ClassesSchedulePlaceholder: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Brand.primary)
            Text("Classes Schedule Coming Soon")
                .font(.title3.bold())
            Text("This will show the full schedule of group classes.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.platformGroupedBackground)
        .navigationTitle("Classes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
