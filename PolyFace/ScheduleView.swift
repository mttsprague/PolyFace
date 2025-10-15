//
//  ScheduleView.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import SwiftUI

struct ScheduleView: View {
    @ObservedObject var scheduleService: ScheduleService

    var body: some View {
        List {
            if scheduleService.isLoading && scheduleService.upcoming.isEmpty {
                ProgressView()
            } else {
                ForEach(scheduleService.upcoming) { slot in
                    SessionRow(slot: slot)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Schedule")
        .task {
            if scheduleService.upcoming.isEmpty {
                await scheduleService.loadUpcoming()
            }
        }
    }
}
