//
//  WaiverAgreementView.swift
//  PolyFace
//
//  Created by GitHub Copilot
//

import SwiftUI

struct WaiverAgreementView: View {
    @Environment(\.dismiss) private var dismiss
    let onWaiverSigned: (WaiverSignature) -> Void
    
    @State private var isParticipantMinor = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var hasAgreed = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var canSubmit: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !email.isEmpty &&
        !phoneNumber.isEmpty &&
        hasAgreed &&
        isValidEmail(email)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Release of Liability")
                            .font(.displaySmall)
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text("Please read carefully and agree to the terms below")
                            .font(.bodyMedium)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.top, Spacing.md)
                    
                    // Waiver Content
                    CardView {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("RELEASE OF LIABILITY AND INDEMNIFICATION AGREEMENT")
                                .font(.headingSmall)
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            ScrollView {
                                Text(waiverText)
                                    .font(.bodySmall)
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .lineSpacing(4)
                            }
                            .frame(height: 250)
                            .padding(Spacing.sm)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(CornerRadius.sm)
                        }
                    }
                    
                    // Minor Toggle
                    CardView {
                        Toggle(isOn: $isParticipantMinor) {
                            VStack(alignment: .leading, spacing: Spacing.xxs) {
                                Text("Participant is under 18 years old")
                                    .font(.bodyMedium)
                                    .foregroundStyle(AppTheme.textPrimary)
                                
                                Text(isParticipantMinor ? "Parent/Guardian information required" : "Participant will sign for themselves")
                                    .font(.bodySmall)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .tint(AppTheme.primary)
                    }
                    
                    // Signatory Information
                    CardView {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text(isParticipantMinor ? "Parent/Guardian Acknowledgment" : "Participant Acknowledgment")
                                .font(.headingSmall)
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            VStack(spacing: Spacing.sm) {
                                CustomTextField(
                                    placeholder: "First Name",
                                    text: $firstName,
                                    icon: "person.fill"
                                )
                                .textContentType(.givenName)
                                .autocapitalization(.words)
                                
                                CustomTextField(
                                    placeholder: "Last Name",
                                    text: $lastName,
                                    icon: "person.fill"
                                )
                                .textContentType(.familyName)
                                .autocapitalization(.words)
                                
                                CustomTextField(
                                    placeholder: "Email Address",
                                    text: $email,
                                    icon: "envelope.fill"
                                )
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                
                                CustomTextField(
                                    placeholder: "Phone Number",
                                    text: $phoneNumber,
                                    icon: "phone.fill"
                                )
                                .textContentType(.telephoneNumber)
                                .keyboardType(.phonePad)
                            }
                        }
                    }
                    
                    // Agreement Checkbox
                    CardView {
                        Button {
                            hasAgreed.toggle()
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: hasAgreed ? "checkmark.square.fill" : "square")
                                    .font(.title2)
                                    .foregroundStyle(hasAgreed ? AppTheme.primary : AppTheme.textSecondary)
                                
                                Text("I have read, understood, and agree to all terms, conditions, and provisions stated above.")
                                    .font(.bodyMedium)
                                    .foregroundStyle(AppTheme.textPrimary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Submit Button
                    Button {
                        submitWaiver()
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Submit Agreement")
                        }
                        .font(.headingSmall)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!canSubmit)
                    .padding(.bottom, Spacing.xl)
                }
                .padding(.horizontal, Spacing.lg)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Waiver Agreement")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func submitWaiver() {
        guard canSubmit else {
            errorMessage = "Please fill out all fields and agree to the terms."
            showingError = true
            return
        }
        
        let signature = WaiverSignature(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            isMinor: isParticipantMinor,
            signedAt: Date()
        )
        
        onWaiverSigned(signature)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
}

// MARK: - Waiver Text Content

private let waiverText = """
I, hereby acknowledge that I am voluntarily participating in volleyball lessons offered by Polyface Volleyball Academy. I understand that participation in such activities involves inherent risks, including but not limited to the risk of injury, property damage, or death. I hereby assume all risks associated with my participation in volleyball lessons and agree to release Polyface Volleyball Academy, its coaches, instructors, employees, agents, and representatives from any and all liability arising from my participation in the lessons.

I understand and acknowledge that Polyface Volleyball Academy has taken measures to ensure the safety of its participants, but I am also aware that accidents and injuries can still occur. I agree to follow all rules and guidelines set forth by Polyface Volleyball Academy and its coaches and instructors, and I acknowledge that failure to do so may increase the risk of injury or harm to myself or others.

I hereby waive and release any and all claims, demands, causes of action, suits, and judgments of any nature whatsoever, whether known or unknown, that I may have against Polyface Volleyball Academy, its coaches, instructors, employees, agents, and representatives arising out of or in connection with my participation in volleyball lessons.

I further agree to indemnify and hold harmless Polyface Volleyball Academy, its coaches, instructors, employees, agents, and representatives from any and all claims, demands, causes of action, suits, and judgments of any nature whatsoever, whether known or unknown, brought by any third party arising out of or in connection with my participation in volleyball lessons.

I understand that this release of liability and indemnification agreement is binding upon me, my heirs, executors, administrators, and assigns, and is governed by the laws of the state in which the lessons are held.

IMAGE/VIDEO/LIKENESS RELEASE FORM FOR SOCIAL MEDIA

I authorize Polyface Volleyball Academy to use my image, video, and likeness for social media posts and marketing materials without compensation. I acknowledge that my image and/or video may be edited or modified, and used in multiple ways and contexts indefinitely. By signing below, I allow Polyface Volleyball Academy to use and potentially profit from image, video, and likeness with full release.

By completing and digitally signing this form, I acknowledge that I have read, understood, and agreed to all terms, conditions, and provisions stated herein.
"""

// MARK: - Waiver Signature Model

struct WaiverSignature {
    let firstName: String
    let lastName: String
    let email: String
    let phoneNumber: String
    let isMinor: Bool
    let signedAt: Date
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
}

// MARK: - Custom TextField Component

private struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .font(.bodyMedium)
        }
        .padding(Spacing.md)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(CornerRadius.sm)
    }
}

#Preview {
    WaiverAgreementView { signature in
        print("Waiver signed by: \(signature.fullName)")
    }
}
