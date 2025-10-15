//
//  ScheduleService.swift
//  PolyFace
//
//  Created by Matthew Sprague on 10/14/25.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class ScheduleService: ObservableObject {
    @Published private(set) var upcoming: [AvailabilitySlot] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    
    // Day slots for Book view
    @Published private(set) var daySlots: [AvailabilitySlot] = []
    @Published private(set) var isLoadingDay = false
    
    // Month dots for Book view
    @Published private(set) var monthAvailability: [Date: Int] = [:]
    @Published private(set) var isLoadingMonth = false
    
    private let db = Firestore.firestore()
    
    func loadUpcoming(limit: Int = 20) async {
        isLoading = true
        errorMessage = nil
        do {
            let now = Timestamp(date: Date())
            let snap = try await db.collectionGroup("schedules")
                .whereField("status", isEqualTo: "open")
                .whereField("startTime", isGreaterThanOrEqualTo: now)
                .order(by: "startTime", descending: false)
                .limit(to: limit)
                .getDocuments()
            
            let slots: [AvailabilitySlot] = snap.documents.compactMap { doc in
                decodeSlot(from: doc)
            }
            self.upcoming = slots
        } catch {
            self.errorMessage = error.localizedDescription
            print("ScheduleService: failed to load upcoming slots: \(error)")
        }
        isLoading = false
    }

    // Load open slots for a specific trainer on a specific day
    func loadOpenSlots(for trainerId: String, on date: Date) async {
        isLoadingDay = true
        defer { isLoadingDay = false }
        errorMessage = nil
        
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
        
        do {
            let startTS = Timestamp(date: startOfDay)
            let endTS = Timestamp(date: endOfDay)
            
            let snap = try await db
                .collection("trainers")
                .document(trainerId)
                .collection("schedules")
                .whereField("status", isEqualTo: "open")
                .whereField("startTime", isGreaterThanOrEqualTo: startTS)
                .whereField("startTime", isLessThan: endTS)
                .order(by: "startTime", descending: false)
                .getDocuments()
            
            let slots: [AvailabilitySlot] = snap.documents.compactMap { decodeSlot(from: $0) }
            self.daySlots = slots
        } catch {
            self.errorMessage = error.localizedDescription
            print("ScheduleService: failed to load day slots: \(error)")
            self.daySlots = []
        }
    }

    // Load availability counts (dots) for a month for a specific trainer
    func loadMonthAvailability(for trainerId: String, monthStart: Date) async {
        isLoadingMonth = true
        defer { isLoadingMonth = false }
        errorMessage = nil
        
        let cal = Calendar.current
        let start = cal.date(from: cal.dateComponents([.year, .month], from: monthStart)) ?? cal.startOfDay(for: monthStart)
        let monthEnd = cal.date(byAdding: DateComponents(month: 1), to: start)!
        
        do {
            let startTS = Timestamp(date: start)
            let endTS = Timestamp(date: monthEnd)
            
            let snap = try await db
                .collection("trainers")
                .document(trainerId)
                .collection("schedules")
                .whereField("status", isEqualTo: "open")
                .whereField("startTime", isGreaterThanOrEqualTo: startTS)
                .whereField("startTime", isLessThan: endTS)
                .getDocuments()
            
            var counts: [Date: Int] = [:]
            for doc in snap.documents {
                guard let slot = decodeSlot(from: doc) else { continue }
                let dayKey = cal.startOfDay(for: slot.startTime)
                counts[dayKey, default: 0] += 1
            }
            self.monthAvailability = counts
        } catch {
            self.errorMessage = error.localizedDescription
            print("ScheduleService: failed to load month availability: \(error)")
            self.monthAvailability = [:]
        }
    }

    // Clear state when user is logged out
    func clearForLogout() {
        upcoming = []
        daySlots = []
        monthAvailability = [:]
        errorMessage = nil
        isLoading = false
        isLoadingDay = false
        isLoadingMonth = false
    }

    // Helpers you may call from other APIs you add later
    func decodeSlot(from doc: QueryDocumentSnapshot) -> AvailabilitySlot? {
        let data = doc.data()
        guard
            let start = Self.date(from: data["startTime"]),
            let end = Self.date(from: data["endTime"])
        else { return nil }

        let trainerId = doc.reference.parent.parent?.documentID
        return AvailabilitySlot(
            id: doc.documentID,
            trainerId: trainerId,
            title: data["title"] as? String,
            status: data["status"] as? String,
            startTime: start,
            endTime: end
        )
    }

    private static func date(from any: Any?) -> Date? {
        if let ts = any as? Timestamp { return ts.dateValue() }
        if let d = any as? Date { return d }
        if let dict = any as? [String: Any], let seconds = dict["_seconds"] as? TimeInterval {
            return Date(timeIntervalSince1970: seconds)
        }
        return nil
    }
}

