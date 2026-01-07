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
POLYFACE VOLLEYBALL ACADEMY

RELEASE OF LIABILITY, ASSUMPTION OF RISK, AND INDEMNIFICATION AGREEMENT

I acknowledge that I am voluntarily participating in volleyball lessons, training sessions, camps, or related activities offered by Polyface Volleyball Academy ("PVA").

I understand that participation in volleyball activities involves inherent risks, including but not limited to physical contact with other participants, falls, collisions, impact with volleyballs or equipment, overuse injuries, property damage, and serious injury or death. I knowingly and voluntarily assume all such risks, whether known or unknown, associated with my participation.

I hereby release, waive, and discharge Polyface Volleyball Academy, and its owners, coaches, instructors, employees, agents, and representatives from any and all claims, demands, actions, or causes of action arising out of or related to my participation in PVA activities, including claims arising from the ordinary negligence of Polyface Volleyball Academy or its coaches, instructors, employees, agents, or representatives.

This release does not apply to acts of gross negligence, recklessness, or intentional misconduct.

I acknowledge that Polyface Volleyball Academy has taken reasonable steps to provide a safe training environment; however, I understand that accidents and injuries may still occur. I agree to follow all rules, safety instructions, and guidelines provided by PVA and its staff, and I acknowledge that failure to do so may increase the risk of injury to myself or others.

I further agree to indemnify and hold harmless Polyface Volleyball Academy, and its owners, coaches, instructors, employees, agents, and representatives from any and all claims, demands, damages, losses, or expenses (including reasonable attorneys' fees) brought by any third party arising out of or related to my participation in PVA activities.

MINOR PARTICIPANTS (If Applicable)

If the participant is under eighteen (18) years of age, I represent and warrant that I am the parent or legal guardian of the minor participant. I consent to the minor's participation in Polyface Volleyball Academy activities and execute this agreement on behalf of both myself and the minor, releasing and waiving claims as described above to the fullest extent permitted by Tennessee law.

IMAGE / VIDEO / LIKENESS RELEASE

I grant Polyface Volleyball Academy permission to photograph, record, or otherwise capture my image, voice, or likeness (or that of the minor participant) during PVA activities and to use such media for lawful promotional, marketing, educational, and social media purposes, without compensation. I understand that such media may be edited and used in various formats and platforms for an indefinite period.

ACKNOWLEDGMENT AND ELECTRONIC ACCEPTANCE

By clicking "I Agree", I acknowledge that I have read and understand this Release of Liability, Assumption of Risk, and Media Release Agreement, and that I am voluntarily giving up certain legal rights, including the right to sue for claims arising from the ordinary negligence of Polyface Volleyball Academy.

This agreement shall be governed by and construed in accordance with the laws of the State of Tennessee
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
