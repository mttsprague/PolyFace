//
//  AdminPanelView.swift
//  PolyFace
//
//  Created by Assistant on 12/31/25.
//

import SwiftUI

struct AdminPanelView: View {
    @StateObject private var adminService = AdminService()
    @StateObject private var classesService = ClassesService()
    @StateObject private var trainersService = TrainersService()
    @StateObject private var packagesService = PackagesService()
    @State private var showingCreateClass = false
    @State private var alertItem: AlertItem?
    @State private var tabSelection: AdminTab = .passes
    
    // Pass management states
    @State private var selectedClient: SimpleUser?
    @State private var selectedPassType: String = "private"
    @State private var passQuantity: Int = 1
    @State private var isAddingPass = false
    
    enum AdminTab: String, CaseIterable {
        case passes = "Passes"
        case classes = "Classes"
    }
    
    var body: some View {
        NavigationView {
            Group {
                if adminService.isLoading {
                    ProgressView("Checking permissions...")
                        .tint(AppTheme.primary)
                } else if !adminService.isAdmin {
                    EmptyStateView(
                        icon: "lock.shield",
                        title: "Admin Access Required",
                        message: "You don't have permission to access this area."
                    )
                } else {
                    adminContent
                }
            }
            .navigationTitle("Admin Panel")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if adminService.isAdmin && tabSelection == .classes {
                        Button {
                            showingCreateClass = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.primary)
                        }
                    } else {
                        EmptyView()
                    }
                }
            }
            .sheet(isPresented: $showingCreateClass) {
                CreateClassView(adminService: adminService, trainersService: trainersService) {
                    Task { await classesService.loadOpenClasses() }
                }
            }
            .alert(item: $alertItem) { item in
                Alert(title: Text(item.title), message: Text(item.message))
            }
        }
        .task {
            await adminService.checkAdminStatus()
            if adminService.isAdmin {
                await classesService.loadOpenClasses()
                await trainersService.loadAll()
                await adminService.loadAllUsers()
            }
        }
    }
    
    private var adminContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Tab selector
                Picker("Tab", selection: $tabSelection) {
                    Text("Passes").tag(AdminTab.passes)
                    Text("Classes").tag(AdminTab.classes)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)
                
                // Content based on tab
                if tabSelection == .passes {
                    passesContent
                } else {
                    classesContent
                }
            }
            .padding(.bottom, Spacing.xxxl)
        }
        .background(Color.platformGroupedBackground.ignoresSafeArea())
        .refreshable {
            if tabSelection == .classes {
                await classesService.loadOpenClasses()
            } else {
                await adminService.loadAllUsers()
            }
        }
    }
    
    // MARK: - Passes Content
    
    private var passesContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Manage Passes")
                    .font(.headingLarge)
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("Add lesson passes to client accounts")
                    .font(.bodyMedium)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            
            CardView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Client selection
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Select Client")
                            .font(.labelMedium)
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        Menu {
                            ForEach(adminService.allUsers) { user in
                                Button {
                                    selectedClient = user
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text("\(user.firstName) \(user.lastName)")
                                        if !user.athleteName.isEmpty {
                                            Text("Athlete: \(user.athleteName)")
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedClient != nil ? "\(selectedClient!.firstName) \(selectedClient!.lastName)" : "Choose a client")
                                    .font(.bodyMedium)
                                    .foregroundStyle(selectedClient != nil ? AppTheme.textPrimary : AppTheme.textSecondary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .padding(Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                                    .fill(Color.platformGroupedBackground)
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Pass type selection
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Pass Type")
                            .font(.labelMedium)
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        Menu {
                            Button {
                                selectedPassType = "private"
                            } label: {
                                Text("Private Lesson Pass (1 athlete)")
                            }
                            Button {
                                selectedPassType = "2_athlete"
                            } label: {
                                Text("2-Athlete Pass")
                            }
                            Button {
                                selectedPassType = "3_athlete"
                            } label: {
                                Text("3-Athlete Pass")
                            }
                            Button {
                                selectedPassType = "class_pass"
                            } label: {
                                Text("Class Pass")
                            }
                        } label: {
                            HStack {
                                Text(passTypeName(selectedPassType))
                                    .font(.bodyMedium)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(AppTheme.textTertiary)
                            }
                            .padding(Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                                    .fill(Color.platformGroupedBackground)
                            )
                        }
                    }
                    
                    Divider()
                    
                    // Quantity input
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Number of Passes")
                            .font(.labelMedium)
                            .foregroundStyle(AppTheme.textSecondary)
                        
                        Stepper(value: $passQuantity, in: 1...100) {
                            HStack {
                                Text("\(passQuantity) pass\(passQuantity == 1 ? "" : "es")")
                                    .font(.headingSmall)
                                    .foregroundStyle(AppTheme.primary)
                                Spacer()
                            }
                        }
                        .padding(Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                                .fill(AppTheme.primary.opacity(0.08))
                        )
                    }
                    
                    // Submit button
                    Button {
                        Task { await addPassToClient() }
                    } label: {
                        HStack {
                            if isAddingPass {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }
                            Text(isAddingPass ? "Adding Pass..." : "Add Pass to Client")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selectedClient == nil || isAddingPass)
                    .opacity(selectedClient != nil ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
    }
    
    // MARK: - Classes Content
    
    private var classesContent: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Manage Classes")
                    .font(.headingLarge)
                    .foregroundStyle(AppTheme.textPrimary)
                
                Text("\(classesService.classes.count) active classes")
                    .font(.bodyMedium)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            
            if classesService.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.primary)
                    Spacer()
                }
                .padding(Spacing.xl)
            } else if classesService.classes.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "No Classes Yet",
                    message: "Create your first class to get started.",
                    action: { showingCreateClass = true },
                    actionTitle: "Create Class"
                )
                .padding(.horizontal, Spacing.lg)
            } else {
                VStack(spacing: Spacing.sm) {
                        ForEach(classesService.classes) { classItem in
                            AdminClassCard(
                                classItem: classItem,
                                onToggleRegistration: { isOpen in
                                    Task {
                                        do {
                                            try await adminService.toggleClassRegistration(
                                                classId: classItem.id ?? "",
                                                isOpen: isOpen
                                            )
                                            await classesService.loadOpenClasses()
                                        } catch {
                                            alertItem = AlertItem(
                                                title: "Error",
                                                message: error.localizedDescription
                                            )
                                        }
                                    }
                                },
                                onDelete: {
                                    Task {
                                        do {
                                            try await adminService.deleteClass(classId: classItem.id ?? "")
                                            await classesService.loadOpenClasses()
                                        } catch {
                                            alertItem = AlertItem(
                                                title: "Error",
                                                message: error.localizedDescription
                                            )
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                }
            }
        }
    
    // MARK: - Helper Functions
    
    private func passTypeName(_ type: String) -> String {
        switch type {
        case "private":
            return "Private Lesson Pass (1 athlete)"
        case "2_athlete":
            return "2-Athlete Pass"
        case "3_athlete":
            return "3-Athlete Pass"
        case "class_pass":
            return "Class Pass"
        default:
            return "Unknown"
        }
    }
    
    private func addPassToClient() async {
        guard let client = selectedClient else { return }
        
        isAddingPass = true
        
        do {
            try await adminService.addPassToClient(
                clientId: client.id,
                passType: selectedPassType,
                totalLessons: passQuantity
            )
            
            // Show success alert
            alertItem = AlertItem(
                title: "Pass Added",
                message: "Successfully added \(passQuantity) \(passTypeName(selectedPassType))\(passQuantity == 1 ? "" : "s") to \(client.firstName) \(client.lastName)'s account."
            )
            
            // Reset selections
            selectedClient = nil
            selectedPassType = "private"
            passQuantity = 1
            
            // Refresh data
            await adminService.loadAllUsers()
            await packagesService.loadMyPackages()
            
        } catch {
            alertItem = AlertItem(
                title: "Error",
                message: "Failed to add pass: \(error.localizedDescription)"
            )
        }
        
        isAddingPass = false
    }
}

struct AdminClassCard: View {
    let classItem: GroupClass
    let onToggleRegistration: (Bool) -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(classItem.title)
                            .font(.headingSmall)
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text(classItem.description)
                            .font(.bodySmall)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    if classItem.isOpenForRegistration {
                        BadgeView(text: "Open", color: AppTheme.success)
                    } else {
                        BadgeView(text: "Closed", color: AppTheme.textTertiary)
                    }
                }
                
                Divider()
                
                HStack(spacing: Spacing.md) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "calendar")
                                .font(.labelSmall)
                            Text(classItem.startTime.formatted(date: .abbreviated, time: .omitted))
                                .font(.labelMedium)
                        }
                        
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "clock")
                                .font(.labelSmall)
                            Text("\(classItem.startTime.formatted(date: .omitted, time: .shortened)) - \(classItem.endTime.formatted(date: .omitted, time: .shortened))")
                                .font(.labelMedium)
                        }
                    }
                    .foregroundStyle(AppTheme.textSecondary)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: Spacing.xxs) {
                        Text("\(classItem.currentParticipants)/\(classItem.maxParticipants)")
                            .font(.headingSmall)
                            .foregroundStyle(AppTheme.primary)
                        
                        Text("registered")
                            .font(.labelSmall)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                
                Divider()
                
                HStack(spacing: Spacing.sm) {
                    Button {
                        onToggleRegistration(!classItem.isOpenForRegistration)
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: classItem.isOpenForRegistration ? "pause.circle" : "play.circle")
                                .font(.system(size: 14, weight: .semibold))
                            Text(classItem.isOpenForRegistration ? "Close" : "Open")
                                .font(.labelMedium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                                .fill(classItem.isOpenForRegistration ? AppTheme.warning : AppTheme.success)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button {
                        showingDeleteAlert = true
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Delete")
                                .font(.labelMedium)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.xs, style: .continuous)
                                .fill(AppTheme.error)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .alert("Delete Class", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete this class? This action cannot be undone.")
        }
    }
}

struct CreateClassView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var adminService: AdminService
    @ObservedObject var trainersService: TrainersService
    let onCreated: () -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var maxParticipants = 20
    @State private var location = "Oakwood Community Church"
    @State private var selectedTrainer: Trainer?
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Form {
                Section("Class Details") {
                    TextField("Title", text: $title)
                    // iOS 15-compatible multiline input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.callout)
                            .foregroundStyle(AppTheme.textSecondary)
                        TextEditor(text: $description)
                            .frame(minHeight: 80, maxHeight: 160)
                    }
                    TextField("Location", text: $location)
                }
                
                Section("Head Trainer") {
                    Picker("Select Trainer", selection: $selectedTrainer) {
                        Text("Select a trainer").tag(nil as Trainer?)
                        ForEach(trainersService.trainers) { trainer in
                            Text(trainer.name ?? "Unknown").tag(trainer as Trainer?)
                        }
                    }
                }
                
                Section("Schedule") {
                    DatePicker("Start Time", selection: $startDate)
                    DatePicker("End Time", selection: $endDate)
                }
                
                Section("Capacity") {
                    Stepper("Max Participants: \(maxParticipants)", value: $maxParticipants, in: 1...50)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(AppTheme.error)
                            .font(.bodySmall)
                    }
                }
            }
            .navigationTitle("Create Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createClass() }
                    }
                    .disabled(isCreating || title.isEmpty || description.isEmpty || selectedTrainer == nil)
                }
            }
        }
    }
    
    private func createClass() async {
        guard let trainer = selectedTrainer else {
            errorMessage = "Please select a head trainer"
            return
        }
        // Validate required trainer fields (id and name must be non-optional)
        guard let trainerId = trainer.id, !trainerId.isEmpty,
              let trainerName = trainer.name, !trainerName.isEmpty else {
            errorMessage = "Selected trainer is missing required information."
            return
        }
        
        isCreating = true
        errorMessage = nil
        
        do {
            try await adminService.createClass(
                title: title,
                description: description,
                startTime: startDate,
                endTime: endDate,
                maxParticipants: maxParticipants,
                location: location,
                trainerId: trainerId,
                trainerName: trainerName
            )
            onCreated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isCreating = false
    }
}

struct AlertItem: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
