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
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]
            let subtitle = "Release of Liability and Indemnification Agreement"
            let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
            let subtitleX = (pageWidth - subtitleSize.width) / 2
            subtitle.draw(at: CGPoint(x: subtitleX, y: currentY), withAttributes: subtitleAttributes)
            currentY += subtitleSize.height + 20
            
            // Draw separator line
            context.cgContext.setStrokeColor(UIColor.lightGray.cgColor)
            context.cgContext.setLineWidth(1.0)
            context.cgContext.move(to: CGPoint(x: leftMargin, y: currentY))
            context.cgContext.addLine(to: CGPoint(x: pageWidth - rightMargin, y: currentY))
            context.cgContext.strokePath()
            currentY += 20
            
            // Paragraph style and body attributes
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 4
            paragraphStyle.alignment = .justified
            
            let bodyAttributesWithParagraph: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraphStyle
            ]
            
            // Waiver content
            let waiverContent = """
            I, hereby acknowledge that I am voluntarily participating in volleyball lessons offered by Polyface Volleyball Academy. I understand that participation in such activities involves inherent risks, including but not limited to the risk of injury, property damage, or death. I hereby assume all risks associated with my participation in volleyball lessons and agree to release Polyface Volleyball Academy, its coaches, instructors, employees, agents, and representatives from any and all liability arising from my participation in the lessons.
            
            I understand and acknowledge that Polyface Volleyball Academy has taken measures to ensure the safety of its participants, but I am also aware that accidents and injuries can still occur. I agree to follow all rules and guidelines set forth by Polyface Volleyball Academy and its coaches and instructors, and I acknowledge that failure to do so may increase the risk of injury or harm to myself or others.
            
            I hereby waive and release any and all claims, demands, causes of action, suits, and judgments of any nature whatsoever, whether known or unknown, that I may have against Polyface Volleyball Academy, its coaches, instructors, employees, agents, and representatives arising out of or in connection with my participation in volleyball lessons.
            
            I further agree to indemnify and hold harmless Polyface Volleyball Academy, its coaches, instructors, employees, agents, and representatives from any and all claims, demands, causes of action, suits, and judgments of any nature whatsoever, whether known or unknown, brought by any third party arising out of or in connection with my participation in volleyball lessons.
            
            I understand that this release of liability and indemnification agreement is binding upon me, my heirs, executors, administrators, and assigns, and is governed by the laws of the state in which the lessons are held.
            """
            
            let waiverRect = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 300)
            waiverContent.draw(in: waiverRect, withAttributes: bodyAttributesWithParagraph)
            currentY += 320
            
            // Image/Video Release
            let mediaReleaseTitle = "IMAGE/VIDEO/LIKENESS RELEASE FOR SOCIAL MEDIA"
            let mediaReleaseTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            mediaReleaseTitle.draw(at: CGPoint(x: leftMargin, y: currentY), withAttributes: mediaReleaseTitleAttributes)
            currentY += 20
            
            let mediaReleaseContent = """
            I authorize Polyface Volleyball Academy to use my image, video, and likeness for social media posts and marketing materials without compensation. I acknowledge that my image and/or video may be edited or modified, and used in multiple ways and contexts indefinitely. By signing below, I allow Polyface Volleyball Academy to use and potentially profit from image, video, and likeness with full release.
            """
            
            let mediaReleaseRect = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 80)
            mediaReleaseContent.draw(in: mediaReleaseRect, withAttributes: bodyAttributesWithParagraph)
            currentY += 100
            
            // Acknowledgment statement
            let ackStatement = "By completing and digitally signing this form, I acknowledge that I have read, understood, and agreed to all terms, conditions, and provisions stated herein."
            let ackStatementAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 10),
                .foregroundColor: UIColor.darkGray
            ]
            let ackRect = CGRect(x: leftMargin, y: currentY, width: contentWidth, height: 40)
            ackStatement.draw(in: ackRect, withAttributes: ackStatementAttributes)
            currentY += 60
            
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
