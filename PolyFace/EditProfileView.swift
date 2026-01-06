import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var usersService = UsersService()
    
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var athleteFirstName: String = ""
    @State private var athleteLastName: String = ""
    @State private var athlete2FirstName: String = ""
    @State private var athlete2LastName: String = ""
    @State private var athlete3FirstName: String = ""
    @State private var athlete3LastName: String = ""
    @State private var athletePosition: String = ""
    @State private var athlete2Position: String = ""
    @State private var athlete3Position: String = ""
    @State private var notesForCoach: String = ""
    @State private var emailAddress: String = ""
    @State private var phoneNumber: String = ""
    
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    var body: some View {
        Form {
            Section(header: Text("Parent/Guardian Information")) {
                TextField("First Name", text: $firstName)
                    .autocapitalization(.words)
                TextField("Last Name", text: $lastName)
                    .autocapitalization(.words)
                TextField("Email", text: $emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
            }
            
            Section(header: Text("Primary Athlete Information")) {
                TextField("First Name", text: $athleteFirstName)
                    .autocapitalization(.words)
                TextField("Last Name", text: $athleteLastName)
                    .autocapitalization(.words)
                TextField("Position", text: $athletePosition)
                    .autocapitalization(.words)
            }
            
            Section(header: Text("Second Athlete (Optional)")) {
                TextField("First Name", text: $athlete2FirstName)
                    .autocapitalization(.words)
                TextField("Last Name", text: $athlete2LastName)
                    .autocapitalization(.words)
                TextField("Position", text: $athlete2Position)
                    .autocapitalization(.words)
            }
            
            Section(header: Text("Third Athlete (Optional)")) {
                TextField("First Name", text: $athlete3FirstName)
                    .autocapitalization(.words)
                TextField("Last Name", text: $athlete3LastName)
                    .autocapitalization(.words)
                TextField("Position", text: $athlete3Position)
                    .autocapitalization(.words)
            }
            
            Section(header: Text("Additional Information")) {
                TextEditor(text: $notesForCoach)
                    .frame(minHeight: 100)
                    .overlay(
                        Group {
                            if notesForCoach.isEmpty {
                                Text("Notes for coach...")
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        },
                        alignment: .topLeading
                    )
            }
            
            Section {
                Button(action: saveProfile) {
                    if isSaving {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                            Spacer()
                        }
                    } else {
                        HStack {
                            Spacer()
                            Text("Save Changes")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
                .disabled(isSaving)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isSuccess ? "Success" : "Error", isPresented: $showAlert) {
            Button("OK") {
                if isSuccess {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
        .task {
            await usersService.loadCurrentUserIfAvailable()
            loadProfile()
        }
    }
    
    private func loadProfile() {
        guard let profile = usersService.currentUserProfile else { return }
        
        firstName = profile.firstName ?? ""
        lastName = profile.lastName ?? ""
        athleteFirstName = profile.athleteFirstName ?? ""
        athleteLastName = profile.athleteLastName ?? ""
        athlete2FirstName = profile.athlete2FirstName ?? ""
        athlete2LastName = profile.athlete2LastName ?? ""
        athlete3FirstName = profile.athlete3FirstName ?? ""
        athlete3LastName = profile.athlete3LastName ?? ""
        athletePosition = profile.athletePosition ?? ""
        athlete2Position = profile.athlete2Position ?? ""
        athlete3Position = profile.athlete3Position ?? ""
        notesForCoach = profile.notesForCoach ?? ""
        emailAddress = profile.emailAddress ?? ""
        phoneNumber = profile.phoneNumber ?? ""
    }
    
    private func saveProfile() {
        // Basic validation
        guard !firstName.isEmpty, !lastName.isEmpty else {
            alertMessage = "Please enter your first and last name."
            isSuccess = false
            showAlert = true
            return
        }
        
        guard !athleteFirstName.isEmpty, !athleteLastName.isEmpty else {
            alertMessage = "Please enter your athlete's first and last name."
            isSuccess = false
            showAlert = true
            return
        }
        
        guard !emailAddress.isEmpty else {
            alertMessage = "Please enter your email address."
            isSuccess = false
            showAlert = true
            return
        }
        
        // Email validation
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        guard emailAddress.range(of: emailRegex, options: .regularExpression) != nil else {
            alertMessage = "Please enter a valid email address."
            isSuccess = false
            showAlert = true
            return
        }
        
        isSaving = true
        
        Task {
            do {
                try await usersService.updateUserProfile(
                    firstName: firstName,
                    lastName: lastName,
                    athleteFirstName: athleteFirstName,
                    athleteLastName: athleteLastName,
                    athlete2FirstName: athlete2FirstName.isEmpty ? nil : athlete2FirstName,
                    athlete2LastName: athlete2LastName.isEmpty ? nil : athlete2LastName,
                    athlete3FirstName: athlete3FirstName.isEmpty ? nil : athlete3FirstName,
                    athlete3LastName: athlete3LastName.isEmpty ? nil : athlete3LastName,
                    athletePosition: athletePosition.isEmpty ? nil : athletePosition,
                    athlete2Position: athlete2Position.isEmpty ? nil : athlete2Position,
                    athlete3Position: athlete3Position.isEmpty ? nil : athlete3Position,
                    notesForCoach: notesForCoach.isEmpty ? nil : notesForCoach,
                    emailAddress: emailAddress,
                    phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber
                )
                
                await MainActor.run {
                    isSaving = false
                    isSuccess = true
                    alertMessage = "Profile updated successfully!"
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    isSuccess = false
                    alertMessage = "Failed to update profile: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }
}

struct EditProfileView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EditProfileView()
        }
    }
}
