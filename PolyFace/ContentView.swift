//
//  ContentView.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/12/25.
//

import SwiftUI

// App Root With Tabs
struct AppRootView: View {
    @StateObject private var auth = AuthManager()
    @StateObject private var usersService = UsersService()
    @StateObject private var scheduleService = ScheduleService()
    @StateObject private var trainersService = TrainersService()
    @StateObject private var packagesService = PackagesService()
    @StateObject private var bookingsService = BookingsService()
    @StateObject private var classesService = ClassesService()
    @StateObject private var adminService = AdminService()
    
    @State private var selectedTab = 0
    @State private var bookViewMode = 0

    var body: some View {
        Group {
            if auth.isReady {
                TabView(selection: $selectedTab) {
                    HomeView(usersService: usersService, 
                            scheduleService: scheduleService,
                            classesService: classesService,
                            selectedTab: $selectedTab,
                            bookViewMode: $bookViewMode)
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }
                        .tag(0)

                    BookView(trainersService: trainersService,
                             scheduleService: scheduleService,
                             packagesService: packagesService,
                             usersService: usersService,
                             initialMode: $bookViewMode)
                        .tabItem {
                            Label("Book", systemImage: "calendar.badge.plus")
                        }
                        .tag(1)

                    ProfileView(usersService: usersService,
                                packagesService: packagesService,
                                bookingsService: bookingsService,
                                scheduleService: scheduleService)
                        .environmentObject(auth)
                        .tabItem {
                            Label("Profile", systemImage: "person.crop.circle")
                        }
                        .tag(2)

                    MorePlaceholderView()
                        .tabItem {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                        .tag(3)
                    
                    if adminService.isAdmin {
                        AdminPanelView()
                            .tabItem {
                                Label("Admin", systemImage: "star.fill")
                            }
                            .tag(4)
                    }
                }
                .tint(AppTheme.primary)
                .task {
                    await adminService.checkAdminStatus()
                }
                .onChange(of: auth.isReady) { _, isReady in
                    if isReady {
                        Task {
                            await adminService.checkAdminStatus()
                        }
                    }
                }
            } else {
                VStack(spacing: Spacing.lg) {
                    ProgressView()
                        .tint(AppTheme.primary)
                    Text("Starting…")
                        .font(.bodyLarge)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .task {
            await auth.ensureSignedIn() // Temporary anonymous; replace with Email/Password flow
        }
    }
}

#Preview {
    AppRootView()
}

