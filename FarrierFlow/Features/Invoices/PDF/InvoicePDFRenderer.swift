import CoreText
import Foundation
import UIKit

nonisolated struct InvoicePDFRenderer {
    static let pageBounds = CGRect(x: 0, y: 0, width: 456, height: 792)

    func render(_ content: InvoicePDFContent) throws -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: Self.pageBounds)
        return renderer.pdfData { context in
            let margin: CGFloat = 28
            let contentWidth = Self.pageBounds.width - (margin * 2)
            let contentBottom: CGFloat = 742
            let ink = UIColor(red: 0.11, green: 0.16, blue: 0.14, alpha: 1)
            let secondaryInk = UIColor(red: 0.34, green: 0.38, blue: 0.36, alpha: 1)
            let rule = UIColor(red: 0.83, green: 0.85, blue: 0.84, alpha: 1)
            let sectionFill = UIColor(red: 0.95, green: 0.96, blue: 0.95, alpha: 1)
            let paidFill = UIColor(red: 0.90, green: 0.95, blue: 0.92, alpha: 1)
            let unpaidFill = UIColor(red: 0.94, green: 0.94, blue: 0.93, alpha: 1)
            let regular = UIFont.systemFont(ofSize: 12.5)
            let secondary = UIFont.systemFont(ofSize: 11)
            let label = UIFont.systemFont(ofSize: 10.5, weight: .semibold)
            let emphasis = UIFont.systemFont(ofSize: 13, weight: .semibold)
            let horseFont = UIFont.systemFont(ofSize: 14, weight: .semibold)
            let businessTitle = UIFont.systemFont(ofSize: 19, weight: .semibold)
            let invoiceTitle = UIFont.systemFont(ofSize: 16, weight: .semibold)
            let amountFont = UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .bold)
            let lineAmountFont = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            let invoiceLabel = String(localized: "Invoice")
            let paidLabel = String(localized: "Paid")
            let unpaidLabel = String(localized: "Unpaid")
            let continuedLabel = String(localized: "Continued")
            let billToLabel = String(localized: "Bill To")
            let invoiceDateLabel = String(localized: "Invoice Date")
            let dueDateLabel = String(localized: "Due Date")
            let paymentDateLabel = String(localized: "Payment Date")
            let paymentMethodLabel = String(localized: "Payment Method")
            let paymentReferenceLabel = String(localized: "Payment Reference")
            let paidAmountLabel = String(localized: "Paid Amount")
            let amountDueLabel = String(localized: "Amount Due")
            let invoiceTotalLabel = String(localized: "Invoice Total")
            let totalLabel = String(localized: "Total")
            let noteLabel = String(localized: "Note")
            let unavailableLabel = String(localized: "Unavailable")
            let currencyLocale = content.currencyCode == "USD"
                ? Locale(identifier: "en_US")
                : Locale.current
            var y: CGFloat = margin
            var page = 0

            func attributes(
                _ font: UIFont,
                color: UIColor = ink,
                alignment: NSTextAlignment = .left
            ) -> [NSAttributedString.Key: Any] {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = alignment
                paragraph.lineBreakMode = .byWordWrapping
                return [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph,
                ]
            }

            func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
                ceil((text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes(font),
                    context: nil
                ).height)
            }

            func drawText(
                _ text: String,
                in rect: CGRect,
                font: UIFont = regular,
                color: UIColor = ink,
                alignment: NSTextAlignment = .left
            ) {
                (text as NSString).draw(
                    in: rect,
                    withAttributes: attributes(font, color: color, alignment: alignment)
                )
            }

            func drawRule(
                at ruleY: CGFloat,
                from startX: CGFloat = margin,
                to endX: CGFloat = Self.pageBounds.width - margin
            ) {
                rule.setStroke()
                let path = UIBezierPath()
                path.lineWidth = 0.5
                path.move(to: CGPoint(x: startX, y: ruleY))
                path.addLine(to: CGPoint(x: endX, y: ruleY))
                path.stroke()
            }

            func formattedMoney(_ minorUnits: Int64) -> String {
                guard content.currencyCode == "USD" else {
                    return unavailableLabel
                }
                return MoneyFormatter.usd(
                    minorUnits: minorUnits,
                    locale: currencyLocale
                ) ?? unavailableLabel
            }

            func drawStatus(at statusY: CGFloat) {
                let text = content.status == .paid ? paidLabel : unpaidLabel
                let width = max(54, ceil((text as NSString).size(
                    withAttributes: attributes(label)
                ).width) + 22)
                let x = Self.pageBounds.width - margin - width
                (content.status == .paid ? paidFill : unpaidFill).setFill()
                UIBezierPath(
                    roundedRect: CGRect(x: x, y: statusY, width: width, height: 24),
                    cornerRadius: 12
                ).fill()
                drawText(
                    text,
                    in: CGRect(x: x, y: statusY + 5, width: width, height: 14),
                    font: label,
                    alignment: .center
                )
            }

            func startPage() {
                context.beginPage()
                page += 1
                UIColor.white.setFill()
                UIRectFill(Self.pageBounds)

                drawText(
                    "\(invoiceLabel) \(content.number)  •  \(page)",
                    in: CGRect(x: margin, y: 763, width: contentWidth, height: 14),
                    font: secondary,
                    color: secondaryInk,
                    alignment: .center
                )

                if page == 1 {
                    y = margin
                    let identityWidth: CGFloat = 224
                    let businessHeight = textHeight(
                        content.businessName,
                        font: businessTitle,
                        width: identityWidth
                    )
                    drawText(
                        content.businessName,
                        in: CGRect(
                            x: margin,
                            y: y,
                            width: identityWidth,
                            height: businessHeight
                        ),
                        font: businessTitle
                    )
                    var contactY = y + businessHeight + 7
                    for detail in [
                        content.businessPhone,
                        content.businessEmail,
                        content.businessAddress,
                    ].compactMap({ $0 }) {
                        let detailHeight = textHeight(
                            detail,
                            font: secondary,
                            width: identityWidth
                        )
                        drawText(
                            detail,
                            in: CGRect(
                                x: margin,
                                y: contactY,
                                width: identityWidth,
                                height: detailHeight
                            ),
                            font: secondary,
                            color: secondaryInk
                        )
                        contactY += detailHeight + 3
                    }

                    let summaryX: CGFloat = 272
                    let summaryWidth = Self.pageBounds.width - margin - summaryX
                    drawText(
                        "\(invoiceLabel) \(content.number)",
                        in: CGRect(x: summaryX, y: y, width: summaryWidth, height: 22),
                        font: invoiceTitle,
                        alignment: .right
                    )
                    drawStatus(at: y + 27)
                    drawText(
                        formattedMoney(content.totalMinorUnits),
                        in: CGRect(x: summaryX - 20, y: y + 60, width: summaryWidth + 20, height: 31),
                        font: amountFont,
                        alignment: .right
                    )
                    drawText(
                        content.status == .unpaid ? amountDueLabel : invoiceTotalLabel,
                        in: CGRect(x: summaryX, y: y + 94, width: summaryWidth, height: 15),
                        font: label,
                        color: secondaryInk,
                        alignment: .right
                    )
                    y = max(contactY, y + 111) + 14
                    drawRule(at: y)
                    y += 15
                } else {
                    y = margin
                    drawText(
                        content.businessName,
                        in: CGRect(x: margin, y: y, width: 210, height: 18),
                        font: emphasis
                    )
                    drawText(
                        "\(invoiceLabel) \(content.number) - \(continuedLabel)",
                        in: CGRect(x: 220, y: y, width: 208, height: 18),
                        font: label,
                        alignment: .right
                    )
                    y += 27
                    drawRule(at: y)
                    y += 15
                }
            }

            func drawKeyValue(_ key: String, value: String) {
                let keyWidth: CGFloat = 142
                let valueWidth = contentWidth - keyWidth
                let keyHeight = textHeight(key, font: label, width: keyWidth)
                let valueHeight = textHeight(value, font: regular, width: valueWidth)
                let rowHeight = max(keyHeight, valueHeight)
                drawText(
                    key,
                    in: CGRect(x: margin, y: y, width: keyWidth, height: rowHeight),
                    font: label,
                    color: secondaryInk
                )
                drawText(
                    value,
                    in: CGRect(
                        x: margin + keyWidth,
                        y: y,
                        width: valueWidth,
                        height: rowHeight
                    ),
                    font: regular,
                    alignment: .right
                )
                y += rowHeight + 8
            }

            func drawMetadata() {
                drawKeyValue(
                    invoiceDateLabel,
                    value: content.invoiceDate.formatted(date: .abbreviated, time: .omitted)
                )
                if let dueDate = content.dueDate {
                    drawKeyValue(
                        dueDateLabel,
                        value: dueDate.formatted(date: .abbreviated, time: .omitted)
                    )
                }
                if let payment = content.payment {
                    drawKeyValue(
                        paymentDateLabel,
                        value: payment.receivedAt.formatted(date: .abbreviated, time: .omitted)
                    )
                    drawKeyValue(paidAmountLabel, value: formattedMoney(payment.amountMinorUnits))
                    let method = [payment.method.displayName, payment.otherDescription]
                        .compactMap { $0 }
                        .joined(separator: ": ")
                    drawKeyValue(paymentMethodLabel, value: method)
                    if let reference = payment.reference {
                        drawKeyValue(paymentReferenceLabel, value: reference)
                    }
                }
                y += 7
            }

            func drawBillTo() {
                drawText(
                    billToLabel,
                    in: CGRect(x: margin, y: y, width: contentWidth, height: 18),
                    font: emphasis
                )
                y += 21
                let nameHeight = textHeight(
                    content.clientName,
                    font: horseFont,
                    width: contentWidth
                )
                drawText(
                    content.clientName,
                    in: CGRect(x: margin, y: y, width: contentWidth, height: nameHeight),
                    font: horseFont
                )
                y += nameHeight + 5
                for detail in [content.clientPhone, content.clientEmail].compactMap({ $0 }) {
                    let detailHeight = textHeight(detail, font: secondary, width: contentWidth)
                    drawText(
                        detail,
                        in: CGRect(x: margin, y: y, width: contentWidth, height: detailHeight),
                        font: secondary,
                        color: secondaryInk
                    )
                    y += detailHeight + 3
                }
                y += 13
            }

            func visitHeadingHeight(_ visit: InvoicePDFContent.VisitGroup) -> CGFloat {
                let textWidth = contentWidth - 24
                let locationHeight = textHeight(visit.location, font: emphasis, width: textWidth)
                let addressHeight = visit.address.map {
                    textHeight($0, font: secondary, width: textWidth)
                } ?? 0
                return 10 + 14 + 4 + locationHeight
                    + (visit.address == nil ? 0 : 4 + addressHeight) + 10
            }

            func drawVisitHeading(_ visit: InvoicePDFContent.VisitGroup) {
                let height = visitHeadingHeight(visit)
                sectionFill.setFill()
                UIBezierPath(
                    roundedRect: CGRect(x: margin, y: y, width: contentWidth, height: height),
                    cornerRadius: 5
                ).fill()
                var textY = y + 10
                drawText(
                    visit.date.formatted(date: .abbreviated, time: .omitted),
                    in: CGRect(x: margin + 12, y: textY, width: contentWidth - 24, height: 14),
                    font: label,
                    color: secondaryInk
                )
                textY += 18
                let locationHeight = textHeight(
                    visit.location,
                    font: emphasis,
                    width: contentWidth - 24
                )
                drawText(
                    visit.location,
                    in: CGRect(
                        x: margin + 12,
                        y: textY,
                        width: contentWidth - 24,
                        height: locationHeight
                    ),
                    font: emphasis
                )
                textY += locationHeight + 4
                if let address = visit.address {
                    let addressHeight = textHeight(
                        address,
                        font: secondary,
                        width: contentWidth - 24
                    )
                    drawText(
                        address,
                        in: CGRect(
                            x: margin + 12,
                            y: textY,
                            width: contentWidth - 24,
                            height: addressHeight
                        ),
                        font: secondary,
                        color: secondaryInk
                    )
                }
                y += height + 13
            }

            let lineAmountWidth: CGFloat = 98
            let serviceWidth = contentWidth - lineAmountWidth - 14

            func lineItemHeight(_ item: InvoicePDFContent.LineItem) -> CGFloat {
                let horseHeight = textHeight(item.horseName, font: horseFont, width: contentWidth)
                let serviceHeight = textHeight(item.serviceName, font: regular, width: serviceWidth)
                return horseHeight + 7 + max(serviceHeight, 18) + 15
            }

            func startContinuation(for visit: InvoicePDFContent.VisitGroup) {
                startPage()
                drawVisitHeading(visit)
            }

            func drawLineItem(
                _ item: InvoicePDFContent.LineItem,
                in visit: InvoicePDFContent.VisitGroup
            ) {
                let rowHeight = lineItemHeight(item)
                if y + rowHeight > contentBottom {
                    startContinuation(for: visit)
                }
                let horseHeight = textHeight(
                    item.horseName,
                    font: horseFont,
                    width: contentWidth
                )
                drawText(
                    item.horseName,
                    in: CGRect(x: margin, y: y, width: contentWidth, height: horseHeight),
                    font: horseFont
                )
                let detailY = y + horseHeight + 7
                let serviceHeight = textHeight(
                    item.serviceName,
                    font: regular,
                    width: serviceWidth
                )
                drawText(
                    item.serviceName,
                    in: CGRect(
                        x: margin,
                        y: detailY,
                        width: serviceWidth,
                        height: serviceHeight
                    ),
                    font: regular
                )
                drawText(
                    formattedMoney(item.amountMinorUnits),
                    in: CGRect(
                        x: Self.pageBounds.width - margin - lineAmountWidth,
                        y: detailY,
                        width: lineAmountWidth,
                        height: 19
                    ),
                    font: lineAmountFont,
                    alignment: .right
                )
                y += rowHeight - 7
                drawRule(at: y)
                y += 7
            }

            func drawPaginatedText(_ text: String, font: UIFont) {
                let attributedText = NSAttributedString(
                    string: text,
                    attributes: attributes(font)
                )
                let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
                let fullRange = NSRange(location: 0, length: attributedText.length)
                var remainingRange = fullRange

                while remainingRange.length > 0 {
                    let availableHeight = contentBottom - y
                    if availableHeight < ceil(font.lineHeight) {
                        startPage()
                        continue
                    }
                    var fittedRange = CFRange()
                    _ = CTFramesetterSuggestFrameSizeWithConstraints(
                        framesetter,
                        CFRange(
                            location: remainingRange.location,
                            length: remainingRange.length
                        ),
                        nil,
                        CGSize(width: contentWidth, height: max(0, availableHeight - 1)),
                        &fittedRange
                    )
                    guard fittedRange.length > 0 else {
                        startPage()
                        continue
                    }
                    let fragmentRange = NSRange(
                        location: fittedRange.location,
                        length: fittedRange.length
                    )
                    let fragment = (text as NSString).substring(with: fragmentRange)
                    let fragmentHeight = textHeight(
                        fragment,
                        font: font,
                        width: contentWidth
                    )
                    drawText(
                        fragment,
                        in: CGRect(
                            x: margin,
                            y: y,
                            width: contentWidth,
                            height: fragmentHeight
                        ),
                        font: font
                    )
                    y += fragmentHeight
                    remainingRange = NSRange(
                        location: NSMaxRange(fragmentRange),
                        length: NSMaxRange(fullRange) - NSMaxRange(fragmentRange)
                    )
                    if remainingRange.length > 0 {
                        startPage()
                    }
                }
            }

            startPage()
            drawMetadata()
            drawBillTo()

            for visit in content.visits {
                let firstRowHeight = visit.lineItems.first.map(lineItemHeight) ?? 0
                if y + visitHeadingHeight(visit) + 13 + firstRowHeight > contentBottom {
                    startPage()
                }
                drawVisitHeading(visit)
                for item in visit.lineItems {
                    drawLineItem(item, in: visit)
                }
                y += 13
            }

            if y + 72 > contentBottom {
                startPage()
            }
            let financialLabel = content.status == .unpaid ? amountDueLabel : totalLabel
            drawRule(at: y, from: margin + 150)
            y += 13
            drawText(
                financialLabel,
                in: CGRect(x: margin + 150, y: y + 5, width: 104, height: 20),
                font: emphasis
            )
            drawText(
                formattedMoney(content.totalMinorUnits),
                in: CGRect(x: margin + 244, y: y, width: contentWidth - 244, height: 31),
                font: amountFont,
                alignment: .right
            )
            y += 51

            if let note = content.note {
                if y + 45 > contentBottom {
                    startPage()
                }
                drawText(
                    noteLabel,
                    in: CGRect(x: margin, y: y, width: contentWidth, height: 18),
                    font: emphasis
                )
                y += 23
                drawPaginatedText(note, font: regular)
            }
        }
    }
}
