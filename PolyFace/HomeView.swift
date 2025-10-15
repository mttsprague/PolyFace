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

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Coming Up")
                            .font(.title3.bold())
                            .foregroundStyle(Brand.primary)

                        VStack(spacing: 12) {
                            if scheduleService.isLoading && scheduleService.upcoming.isEmpty {
                                ProgressView().frame(maxWidth: .infinity, alignment: .center)
                            }

                            if !scheduleService.upcoming.isEmpty {
                                ForEach(scheduleService.upcoming.prefix(3)) { slot in
                                    SessionRow(slot: slot)
                                }
                            }

                            if scheduleService.errorMessage != nil {
                                Text("Could not load schedule.")
                                    .foregroundStyle(.secondary)
                            }

                            // Show a hint when logged out (since we don’t load schedules)
                            if !isAuthenticated && scheduleService.upcoming.isEmpty && !scheduleService.isLoading {
                                Text("Sign in to view upcoming availability.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Only show "View Full Schedule" if authenticated
                    if isAuthenticated {
                        NavigationLink {
                            ScheduleView(scheduleService: scheduleService)
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
            // Only load user/schedule data if authenticated
            if isAuthenticated {
                await usersService.loadCurrentUserIfAvailable()
                await scheduleService.loadUpcoming()
            } else {
                // Clear any stale data when logged out
                scheduleService.clearForLogout()
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
}

struct SessionRow: View {
    let slot: AvailabilitySlot

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
                Text(slot.displayTitle).font(.headline)
                Text("\(slot.startTime, style: .date) • \(slot.startTime.formatted(date: .omitted, time: .shortened))–\(slot.endTime.formatted(date: .omitted, time: .shortened))")
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
