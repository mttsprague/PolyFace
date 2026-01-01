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
    @ObservedObject var classesService: ClassesService
    @Environment(\.openURL) private var openURL
    
    @Binding var selectedTab: Int
    @Binding var bookViewMode: Int

    private let venueName = "Oakwood Community Church"
    private let venueAddressLine = "3927 Webb Rd"
    private let venueCityStateZip = "Chattanooga, TN 37416"

    private var isAuthenticated: Bool {
        Auth.auth().currentUser != nil
    }

    var body: some View {
        NavigationView {
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
                        
                        if classesService.upcomingClasses.isEmpty {
                            CardView(padding: Spacing.lg) {
                                VStack(spacing: Spacing.sm) {
                                    Image(systemName: "calendar.badge.clock")
                                        .font(.system(size: 40))
                                        .foregroundStyle(AppTheme.textTertiary)
                                    Text("No upcoming classes")
                                        .font(.bodyMedium)
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Text("Check back soon for new class schedules")
                                        .font(.labelSmall)
                                        .foregroundStyle(AppTheme.textTertiary)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            VStack(spacing: Spacing.sm) {
                                ForEach(classesService.upcomingClasses) { groupClass in
                                    Button {
                                        bookViewMode = 1 // Switch to classes mode
                                        selectedTab = 1 // Switch to Book tab
                                    } label: {
                                        ClassPreviewRow(
                                            groupClass: groupClass,
                                            classesService: classesService
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // CTA Button
                    Button {
                        bookViewMode = 1 // Set to Classes mode
                        selectedTab = 1  // Switch to Book tab
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
            // Load upcoming classes
            await classesService.loadUpcomingClasses()
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

// MARK: - Class Preview Row

private struct ClassPreviewRow: View {
    let groupClass: GroupClass
    @ObservedObject var classesService: ClassesService
    @State private var isRegistered = false

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
                    HStack {
                        Text(groupClass.title)
                            .font(.headingSmall)
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        if isRegistered {
                            BadgeView(text: "Registered", color: AppTheme.success)
                        }
                    }

                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "calendar")
                            .font(.labelSmall)
                        Text(groupClass.startTime.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                            .font(.labelMedium)
                    }
                    .foregroundStyle(AppTheme.textSecondary)

                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "clock")
                            .font(.labelSmall)
                        Text("\(groupClass.startTime.formatted(date: .omitted, time: .shortened)) - \(groupClass.endTime.formatted(date: .omitted, time: .shortened))")
                            .font(.labelMedium)
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                    
                    // Capacity badge
                    if !isRegistered && groupClass.spotsRemaining <= 3 {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "person.2.fill")
                                .font(.labelSmall)
                            Text("\(groupClass.spotsRemaining) spots left")
                                .font(.labelMedium)
                        }
                        .foregroundStyle(AppTheme.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textTertiary)
            }
        }
        .task {
            if let id = groupClass.id {
                isRegistered = await classesService.isRegistered(for: id)
            } else {
                isRegistered = false
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
