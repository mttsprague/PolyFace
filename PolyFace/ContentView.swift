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

    var body: some View {
        Group {
            if auth.isReady {
                TabView {
                    HomeView(usersService: usersService, 
                            scheduleService: scheduleService,
                            classesService: classesService)
                        .tabItem {
                            Label("Home", systemImage: "house.fill")
                        }

                    BookView(trainersService: trainersService,
                             scheduleService: scheduleService,
                             packagesService: packagesService)
                        .tabItem {
                            Label("Book", systemImage: "calendar.badge.plus")
                        }

                    ProfileView(usersService: usersService,
                                packagesService: packagesService,
                                bookingsService: bookingsService,
                                scheduleService: scheduleService)
                        .environmentObject(auth)
                        .tabItem {
                            Label("Profile", systemImage: "person.crop.circle")
                        }

                    MorePlaceholderView()
                        .tabItem {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                    
                    if adminService.isAdmin {
                        AdminPanelView()
                            .tabItem {
                                Label("Admin", systemImage: "star.fill")
                            }
                    }
                }
                .tint(AppTheme.primary)
                .task {
                    await adminService.checkAdminStatus()
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

