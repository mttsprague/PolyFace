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
            } else if scheduleService.upcoming.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    Text("No upcoming availability found.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
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

private struct SessionRow: View {
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
                Text(slot.displayTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(slot.startTime.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())) • \(slot.startTime.formatted(date: .omitted, time: .shortened))–\(slot.endTime.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)

                if let status = slot.status?.capitalized {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(status.lowercased() == "open" ? .green : .secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.platformBackground)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
    }
}
