//
//  MonthCalendarView.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//


import SwiftUI

struct MonthCalendarView: View {
    @Binding var monthStart: Date
    @Binding var selectedDate: Date
    var availabilityByDay: [Date: Int]
    var onMonthChanged: (Date) -> Void

    private let calendar = Calendar.current
    private let weekSymbols = Calendar.current.shortWeekdaySymbols

    var body: some View {
        VStack(spacing: 8) {
            header
            weekdayRow
            grid
        }
        .padding(.horizontal)
    }

    private var header: some View {
        HStack {
            Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left").font(.headline) }
            Spacer()
            Text(monthTitle(for: monthStart)).font(.title3.bold())
            Spacer()
            Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right").font(.headline) }
        }
        .padding(.vertical, 4)
    }

    private var weekdayRow: some View {
        let symbols = shiftedWeekdaySymbols()
        return HStack {
            ForEach(symbols, id: \.self) { symbol in
                Text(symbol).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let days = daysInMonthGrid()
        return VStack(spacing: 8) {
            ForEach(0..<days.count/7, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        let idx = row*7 + col
                        let day = days[idx]
                        dayCell(day)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date?) -> some View {
        Group {
            if let day {
                let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                let count = availabilityByDay[calendar.startOfDay(for: day)] ?? 0

                Button {
                    selectedDate = day
                } label: {
                    VStack(spacing: 4) {
                        Text("\(calendar.component(.day, from: day))")
                            .font(.body.weight(isSelected ? .bold : .regular))
                            .foregroundStyle(isSelected ? .white : .primary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(isSelected ? Brand.primary : .clear))

                        Circle()
                            .fill(count > 0 ? Color.yellow : Color.clear)
                            .frame(width: 6, height: 6)
                            .opacity(count > 0 ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
            }
        }
    }

    private func monthTitle(for date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"; return f.string(from: date)
    }

    private func changeMonth(by delta: Int) {
        if let newStart = calendar.date(byAdding: .month, value: delta, to: monthStart)?.startOfMonth(calendar) {
            monthStart = newStart
            onMonthChanged(newStart)
        }
    }

    private func daysInMonthGrid() -> [Date?] {
        let start = monthStart.startOfMonth(calendar)
        let range = calendar.range(of: .day, in: .month, for: start)!
        let firstWeekdayIndex = calendar.component(.weekday, from: start) - calendar.firstWeekday
        let leading = (firstWeekdayIndex + 7) % 7
        let total = leading + range.count
        let rows = Int(ceil(Double(total) / 7.0))
        var days: [Date?] = Array(repeating: nil, count: rows * 7)

        for day in 0..<range.count {
            if let date = calendar.date(byAdding: .day, value: day, to: start) {
                days[leading + day] = date
            }
        }
        return days
    }

    private func shiftedWeekdaySymbols() -> [String] {
        let symbols = weekSymbols
        let shift = Calendar.current.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }
}

private extension Date {
    func startOfMonth(_ calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: self))!
    }
}
