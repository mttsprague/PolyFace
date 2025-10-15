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

    var body: some View {
        Group {
            if auth.isReady {
                TabView {
                    HomeView(usersService: usersService, scheduleService: scheduleService)
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }

                    BookView(trainersService: trainersService,
                             scheduleService: scheduleService,
                             packagesService: packagesService)
                        .tabItem {
                            Image(systemName: "calendar.badge.plus")
                            Text("Book")
                        }

                    ProfileView(usersService: usersService,
                                packagesService: packagesService,
                                bookingsService: bookingsService,
                                scheduleService: scheduleService)
                        .environmentObject(auth)
                        .tabItem {
                            Image(systemName: "person.crop.circle")
                            Text("Profile")
                        }

                    MorePlaceholderView()
                        .tabItem {
                            Image(systemName: "ellipsis.circle")
                            Text("More")
                        }
                }
            } else {
                ProgressView("Starting…")
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

