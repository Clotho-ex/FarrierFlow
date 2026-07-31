import CoreText
import Foundation
import UIKit

nonisolated struct InvoicePDFRenderer {
    static let pageBounds = CGRect(x: 0, y: 0, width: 612, height: 792)

    func render(_ content: InvoicePDFContent) throws -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: Self.pageBounds)
        return renderer.pdfData { context in
            let margin: CGFloat = 48
            let contentWidth = Self.pageBounds.width - (margin * 2)
            let bottom: CGFloat = Self.pageBounds.height - 48
            let regular = UIFont.systemFont(ofSize: 10)
            let emphasis = UIFont.boldSystemFont(ofSize: 11)
            let title = UIFont.boldSystemFont(ofSize: 18)
            let attributes: (UIFont) -> [NSAttributedString.Key: Any] = {
                [.font: $0, .foregroundColor: UIColor.black]
            }
            let invoiceLabel = String(localized: "Invoice")
            let paidLabel = String(localized: "Paid")
            let unpaidLabel = String(localized: "Unpaid")
            let continuedLabel = String(localized: "Continued")
            let businessLabel = String(localized: "Business")
            let clientLabel = String(localized: "Client")
            let invoiceDateLabel = String(localized: "Invoice Date")
            let dueDateLabel = String(localized: "Due Date")
            let paymentDateLabel = String(localized: "Payment Date")
            let statusLabel = String(localized: "Status")
            let totalLabel = String(localized: "Total")
            let noteLabel = String(localized: "Note")
            let unavailableLabel = String(localized: "Unavailable")
            var y: CGFloat = 0
            var page = 0

            func height(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
                (text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes(font),
                    context: nil
                ).integral.height
            }

            func startPage() {
                context.beginPage()
                page += 1
                y = margin
                ("\(invoiceLabel) \(content.number)" as NSString).draw(
                    at: CGPoint(x: margin, y: y),
                    withAttributes: attributes(title)
                )
                y += 28
                let contextLine = "\(content.businessName)  •  \(content.status == .paid ? paidLabel : unpaidLabel)"
                (contextLine as NSString).draw(
                    at: CGPoint(x: margin, y: y),
                    withAttributes: attributes(regular)
                )
                y += 22
                if page > 1 {
                    (continuedLabel as NSString).draw(
                        at: CGPoint(x: margin, y: y),
                        withAttributes: attributes(regular)
                    )
                    y += 18
                }
            }

            func drawBlock(_ text: String, font: UIFont = regular, indent: CGFloat = 0) {
                let width = contentWidth - indent
                let attributedText = NSAttributedString(
                    string: text,
                    attributes: attributes(font)
                )
                let framesetter = CTFramesetterCreateWithAttributedString(
                    attributedText
                )
                let fullRange = NSRange(location: 0, length: attributedText.length)
                var remainingRange = fullRange

                while remainingRange.length > 0 {
                    var availableHeight = bottom - y
                    if availableHeight < ceil(font.lineHeight) {
                        startPage()
                        availableHeight = bottom - y
                    }

                    var fittedRange = CFRange()
                    _ = CTFramesetterSuggestFrameSizeWithConstraints(
                        framesetter,
                        CFRange(
                            location: remainingRange.location,
                            length: remainingRange.length
                        ),
                        nil,
                        CGSize(width: width, height: max(0, availableHeight - 1)),
                        &fittedRange
                    )

                    guard fittedRange.length > 0 else {
                        startPage()
                        continue
                    }

                    var fragmentRange = NSRange(
                        location: fittedRange.location,
                        length: fittedRange.length
                    )
                    var fragment = (text as NSString).substring(
                        with: fragmentRange
                    )
                    var fragmentHeight = height(
                        fragment,
                        font: font,
                        width: width
                    )
                    while fragmentHeight > availableHeight,
                          fragmentRange.length > 1 {
                        let finalCharacterRange = (text as NSString)
                            .rangeOfComposedCharacterSequence(
                                at: NSMaxRange(fragmentRange) - 1
                            )
                        fragmentRange.length = finalCharacterRange.location
                            - fragmentRange.location
                        fragment = (text as NSString).substring(
                            with: fragmentRange
                        )
                        fragmentHeight = height(
                            fragment,
                            font: font,
                            width: width
                        )
                    }
                    (fragment as NSString).draw(
                        in: CGRect(
                            x: margin + indent,
                            y: y,
                            width: width,
                            height: fragmentHeight
                        ),
                        withAttributes: attributes(font)
                    )
                    y += fragmentHeight
                    remainingRange = NSRange(
                        location: NSMaxRange(fragmentRange),
                        length: NSMaxRange(fullRange) - NSMaxRange(fragmentRange)
                    )

                    if remainingRange.length > 0 {
                        startPage()
                    } else {
                        y += 7
                    }
                }
            }

            startPage()
            drawBlock(businessLabel, font: emphasis)
            drawBlock(content.businessName)
            if let phone = content.businessPhone { drawBlock(phone, indent: 8) }
            if let email = content.businessEmail { drawBlock(email, indent: 8) }
            if let address = content.businessAddress { drawBlock(address, indent: 8) }
            drawBlock(clientLabel, font: emphasis)
            drawBlock(content.clientName)
            if let phone = content.clientPhone { drawBlock(phone, indent: 8) }
            if let email = content.clientEmail { drawBlock(email, indent: 8) }
            drawBlock("\(invoiceDateLabel): \(content.invoiceDate.formatted(date: .abbreviated, time: .omitted))")
            if let dueDate = content.dueDate { drawBlock("\(dueDateLabel): \(dueDate.formatted(date: .abbreviated, time: .omitted))") }
            drawBlock("\(statusLabel): \(content.status == .paid ? paidLabel : unpaidLabel)")
            if let paidAt = content.paidAt { drawBlock("\(paymentDateLabel): \(paidAt.formatted(date: .abbreviated, time: .omitted))") }

            for visit in content.visits {
                let heading = "\(visit.date.formatted(date: .abbreviated, time: .omitted))\n\(visit.location)"
                let addressHeight = visit.address.map { height($0, font: regular, width: contentWidth - 8) + 7 } ?? 0
                if y + height(heading, font: emphasis, width: contentWidth) + addressHeight + 18 > bottom { startPage() }
                drawBlock(heading, font: emphasis)
                if let address = visit.address { drawBlock(address, indent: 8) }
                for item in visit.lineItems {
                    drawBlock("\(item.horseName)\n\(item.serviceName)\n\(MoneyFormatter.usd(minorUnits: item.amountMinorUnits) ?? unavailableLabel)", indent: 16)
                }
            }
            drawBlock("\(totalLabel): \(MoneyFormatter.usd(minorUnits: content.totalMinorUnits) ?? unavailableLabel)", font: emphasis)
            if let note = content.note { drawBlock("\(noteLabel)\n\(note)", font: regular) }
        }
    }
}
