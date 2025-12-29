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
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Hero Header
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Welcome Back")
                            .font(.headingMedium)
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        Text(usersService.currentUser?.displayName ?? "Athlete")
                            .font(.displayMedium)
                            .foregroundStyle(AppTheme.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Spacing.md)

                    // Location Card
                    CardView(padding: Spacing.md) {
                        Button {
                            openInMaps(address: "\(venueAddressLine), \(venueCityStateZip)")
                        } label: {
                            HStack(spacing: Spacing.md) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [AppTheme.primary, AppTheme.primaryLight],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text("PolyFace Volleyball")
                                        .font(.headingSmall)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    
                                    Text(venueName)
                                        .font(.bodyMedium)
                                        .foregroundStyle(AppTheme.textSecondary)
                                    
                                    Text(venueAddressLine)
                                        .font(.bodySmall)
                                        .foregroundStyle(AppTheme.textTertiary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(AppTheme.primary.opacity(0.3))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    // Coming Up Section
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        SectionHeaderView(title: "Upcoming Classes")
                        
                        VStack(spacing: Spacing.sm) {
                            ForEach(comingUpClasses) { item in
                                ClassPreviewRow(item: item)
                            }
                        }
                    }

                    // CTA Button
                    NavigationLink {
                        ClassesSchedulePlaceholder()
                    } label: {
                        Text("View Full Schedule")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, Spacing.md)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.xxxl)
            }
            .background(Color.platformGroupedBackground.ignoresSafeArea())
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
        CardView(padding: Spacing.md) {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.sm, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.secondary, AppTheme.secondaryLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "figure.volleyball")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(item.title)
                        .font(.headingSmall)
                        .foregroundStyle(AppTheme.textPrimary)

                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "calendar")
                            .font(.labelSmall)
                        Text(item.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.labelMedium)
                    }
                    .foregroundStyle(AppTheme.textSecondary)

                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "clock")
                            .font(.labelSmall)
                        Text("\(item.start.formatted(date: .omitted, time: .shortened)) - \(item.end.formatted(date: .omitted, time: .shortened))")
                            .font(.labelMedium)
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
    }
}

// MARK: - Placeholder destination for future Classes schedule

private struct ClassesSchedulePlaceholder: View {
    var body: some View {
        EmptyStateView(
            icon: "calendar.badge.plus",
            title: "Coming Soon",
            message: "Group classes schedule will be available here. Check back later for updates!"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.platformGroupedBackground.ignoresSafeArea())
        .navigationTitle("Classes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
