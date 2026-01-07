//
//  WaiverPDFGenerator.swift
//  PolyFace
//
//  Created by GitHub Copilot
//

import Foundation
import PDFKit

struct WaiverPDFGenerator {
    
    static func generateWaiverPDF(signature: WaiverSignature) -> Data? {
        let pdfMetaData = [
            kCGPDFContextCreator: "Polyface Volleyball Academy",
            kCGPDFContextTitle: "Release of Liability Waiver",
            kCGPDFContextAuthor: signature.fullName
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        // 8.5 x 11 inch page
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var currentY: CGFloat = 60.0
            let leftMargin: CGFloat = 60.0
            let rightMargin: CGFloat = 60.0
            let contentWidth = pageWidth - leftMargin - rightMargin
            
            // Header
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.black
            ]
            let title = "POLYFACE VOLLEYBALL ACADEMY"
            let titleSize = title.size(withAttributes: titleAttributes)
            let titleX = (pageWidth - titleSize.width) / 2
            title.draw(at: CGPoint(x: titleX, y: currentY), withAttributes: titleAttributes)
            currentY += titleSize.height + 10
            
            let subtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            let subtitle = "Release of Liability, Assumption of Risk, and Indemnification Agreement"
            
            // Split subtitle into two lines if needed
            let subtitleLine1 = "Release of Liability, Assumption of Risk,"
            let subtitleLine2 = "and Indemnification Agreement"
            let subtitleSize1 = subtitleLine1.size(withAttributes: subtitleAttributes)
            let subtitleSize2 = subtitleLine2.size(withAttributes: subtitleAttributes)
            let subtitleX1 = (pageWidth - subtitleSize1.width) / 2
            let subtitleX2 = (pageWidth - subtitleSize2.width) / 2
            subtitleLine1.draw(at: CGPoint(x: subtitleX1, y: currentY), withAttributes: subtitleAttributes)
            currentY += subtitleSize1.height + 2
            subtitleLine2.draw(at: CGPoint(x: subtitleX2, y: currentY), withAttributes: subtitleAttributes)
            currentY += subtitleSize2.height + 15
            
            // Draw separator line
            context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            context.cgContext.setLineWidth(1.0)
            context.cgContext.move(to: CGPoint(x: leftMargin, y: currentY))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - rightMargin, y: currentY))
            context.cgContext.strokePath()
            currentY += 20
            
            // Paragraph style and body attributes
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 3
            paragraphStyle.alignment = .justified
            
            let bodyAttributesWithParagraph: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]
            
            // Main waiver content - split into sections to avoid overlap
            let section1 = """
            I acknowledge that I am voluntarily participating in volleyball lessons, training sessions, camps, or related activities offered by Polyface Volleyball Academy ("PVA").

            I understand that participation in volleyball activities involves inherent risks, including but not limited to physical contact with other participants, falls, collisions, impact with volleyballs or equipment, overuse injuries, property damage, and serious injury or death. I knowingly and voluntarily assume all such risks, whether known or unknown, associated with my participation.

            I hereby release, waive, and discharge Polyface Volleyball Academy, and its owners, coaches, instructors, employees, agents, and representatives from any and all claims, demands, actions, or causes of action arising out of or related to my participation in PVA activities, including claims arising from the ordinary negligence of Polyface Volleyball Academy or its coaches, instructors, employees, agents, or representatives.
            """
            
            let section1Rect = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 130)
            section1.draw(in: section1Rect, withAttributes: bodyAttributesWithParagraph)
            currentY += 135
            
            let section2 = """
            This release does not apply to acts of gross negligence, recklessness, or intentional misconduct.

            I acknowledge that Polyface Volleyball Academy has taken reasonable steps to provide a safe training environment; however, I understand that accidents and injuries may still occur. I agree to follow all rules, safety instructions, and guidelines provided by PVA and its staff, and I acknowledge that failure to do so may increase the risk of injury to myself or others.

            I further agree to indemnify and hold harmless Polyface Volleyball Academy, and its owners, coaches, instructors, employees, agents, and representatives from any and all claims, demands, damages, losses, or expenses (including reasonable attorneys' fees) brought by any third party arising out of or related to my participation in PVA activities.
            """
            
            let section2Rect = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 120)
            section2.draw(in: section2Rect, withAttributes: bodyAttributesWithParagraph)
            currentY += 125
            
            // Minor Participants Section
            let minorTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: UIColor.black
            ]
            let minorTitle = "MINOR PARTICIPANTS (If Applicable)"
            minorTitle.draw(at: CGPoint(x: leftMargin, y: currentY), withAttributes: minorTitleAttributes)
            currentY += 18
            
            let minorContent = """
            If the participant is under eighteen (18) years of age, I represent and warrant that I am the parent or legal guardian of the minor participant. I consent to the minor's participation in Polyface Volleyball Academy activities and execute this agreement on behalf of both myself and the minor, releasing and waiving claims as described above to the fullest extent permitted by Tennessee law.
            """
            
            let minorRect = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 70)
            minorContent.draw(in: minorRect, withAttributes: bodyAttributesWithParagraph)
            currentY += 75
            
            // Image/Video Release
            let mediaReleaseTitle = "IMAGE / VIDEO / LIKENESS RELEASE"
            let mediaReleaseTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 11),
                .foregroundColor: UIColor.black
            ]
            mediaReleaseTitle.draw(at: CGPoint(x: leftMargin, y: currentY), withAttributes: mediaReleaseTitleAttributes)
            currentY += 18
            
            let mediaReleaseContent = """
            I grant Polyface Volleyball Academy permission to photograph, record, or otherwise capture my image, voice, or likeness (or that of the minor participant) during PVA activities and to use such media for lawful promotional, marketing, educational, and social media purposes, without compensation. I understand that such media may be edited and used in various formats and platforms for an indefinite period.
            """
            
            let mediaReleaseRect = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 65)
            mediaReleaseContent.draw(in: mediaReleaseRect, withAttributes: bodyAttributesWithParagraph)
            currentY += 70
            
            // Acknowledgment Section
            let ackTitle = "ACKNOWLEDGMENT AND ELECTRONIC ACCEPTANCE"
            ackTitle.draw(at: CGPoint(x: leftMargin, y: currentY), withAttributes: mediaReleaseTitleAttributes)
            currentY += 18
            
            let ackContent = """
            By clicking "I Agree", I acknowledge that I have read and understand this Release of Liability, Assumption of Risk, and Media Release Agreement, and that I am voluntarily giving up certain legal rights, including the right to sue for claims arising from the ordinary negligence of Polyface Volleyball Academy.

            This agreement shall be governed by and construed in accordance with the laws of the State of Tennessee
            """
            
            let ackContentRect = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 60)
            ackContent.draw(in: ackContentRect, withAttributes: bodyAttributesWithParagraph)
            currentY += 70
            
            // Draw separator line
            context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            context.cgContext.move(to: CGPoint(x: leftMargin, y: currentY))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - rightMargin, y: currentY))
            context.cgContext.strokePath()
            currentY += 20
            
            // Signature section
            let sigHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.black
            ]
            let sigHeader = signature.isMinor ? "PARENT/GUARDIAN ACKNOWLEDGMENT" : "PARTICIPANT ACKNOWLEDGMENT"
            sigHeader.draw(at: CGPoint(x: leftMargin, y: currentY), withAttributes: sigHeaderAttributes)
            currentY += 30
            
            let fieldAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.darkGray
            ]
            let valueAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            
            // Name
            "Name:".draw(at: CGPoint(x: leftMargin, y: currentY), withAttributes: fieldAttributes)
            signature.fullName.draw(at: CGPoint(x: leftMargin + 60, y: currentY), withAttributes: valueAttributes)
            currentY += 25
            
            // Email
            "Email:".draw(at: CGPoint(x: leftMargin, y: currentY), withAttributes: fieldAttributes)
            signature.email.draw(at: CGPoint(x: leftMargin + 60, y: currentY), withAttributes: valueAttributes)
            currentY += 25
            
            // Phone
            "Phone:".draw(at: CGPoint(x: leftMargin, y: currentY), withAttributes: fieldAttributes)
            signature.phoneNumber.draw(at: CGPoint(x: leftMargin + 60, y: currentY), withAttributes: valueAttributes)
            currentY += 25
            
            // Date signed
            "Date Signed:".draw(at: CGPoint(x: leftMargin, y: currentY), withAttributes: fieldAttributes)
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            let dateString = dateFormatter.string(from: signature.signedAt)
            dateString.draw(at: CGPoint(x: leftMargin + 90, y: currentY), withAttributes: valueAttributes)
            currentY += 25
            
            // Digital signature statement
            "Digital Signature:".draw(at: CGPoint(x: leftMargin, y: currentY), withAttributes: fieldAttributes)
            currentY += 20
            
            let digitalSigAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 14),
                .foregroundColor: UIColor.blue
            ]
            signature.fullName.draw(at: CGPoint(x: leftMargin + 20, y: currentY), withAttributes: digitalSigAttributes)
            currentY += 30
            
            // Footer note
            let footerNote = "This document was digitally signed through the Polyface Volleyball Academy mobile application."
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.gray
            ]
            let footerRect = CGRect(x: leftMargin, y: pageHeight - 60, width: contentWidth, height: 40)
            footerNote.draw(in: footerRect, withAttributes: footerAttributes)
        }
        
        return data
    }
}
