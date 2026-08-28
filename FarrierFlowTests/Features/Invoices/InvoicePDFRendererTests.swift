import Foundation
import PDFKit
import Testing
@testable import FarrierFlow

@Suite("Invoice PDF renderer", .serialized)
struct InvoicePDFRendererTests {
    @Test func rendersStructuredInvoiceHierarchy() throws {
        let content = InvoicePDFContent(
            number: "0148",
            invoiceDate: Date(timeIntervalSinceReferenceDate: 1_000),
            dueDate: Date(timeIntervalSinceReferenceDate: 2_000),
            status: .unpaid,
            payment: nil,
            currencyCode: "USD",
            businessName: "Carter Farrier Service",
            businessPhone: "555-0100",
            businessEmail: "office@example.com",
            businessAddress: "1 Main Street",
            clientName: "Alex Carter",
            clientPhone: "555-0101",
            clientEmail: "alex@example.com",
            visits: [
                .init(
                    date: Date(timeIntervalSinceReferenceDate: 500),
                    location: "North Field",
                    address: "25 Stable Lane",
                    lineItems: [
                        .init(
                            horseName: "Milo",
                            serviceName: "Full Set",
                            amountMinorUnits: 12_500
                        ),
                    ]
                ),
                .init(
                    date: Date(timeIntervalSinceReferenceDate: 750),
                    location: "Cedar Ridge Stables",
                    address: nil,
                    lineItems: [
                        .init(
                            horseName: "Sable",
                            serviceName: "Therapeutic Trim and Hoof Balance Assessment",
                            amountMinorUnits: 8_500
                        ),
                    ]
                ),
            ],
            totalMinorUnits: 21_000,
            note: "Thank you for your business. Payment is due within 14 days."
        )

        let data = try InvoicePDFRenderer().render(content)
        let document = try #require(PDFDocument(data: data))
        let text = document.string ?? ""

        #expect(document.pageCount == 1)
        for heading in [
            "Invoice",
            "Bill To",
            "Invoice Date",
            "Due Date",
            "Amount Due",
            "Note",
        ] {
            #expect(text.contains(heading))
        }
        #expect(text.contains("Milo"))
        #expect(text.contains("Full Set"))
        #expect(text.contains("$125.00"))
        #expect(text.contains("$85.00"))
        #expect(text.contains("$210.00"))
        #expect(!text.contains("$125,00"))
        #expect(!text.contains("Horse"))
    }

    @Test func rendersNarrowMobileReadablePDF() throws {
        let content = InvoicePDFContent(number: "0001", invoiceDate: .now, dueDate: nil, status: .unpaid, payment: nil, currencyCode: "USD", businessName: "Farrier", businessPhone: nil, businessEmail: nil, businessAddress: nil, clientName: "Client", clientPhone: nil, clientEmail: nil, visits: [], totalMinorUnits: 0, note: nil)
        let data = try InvoicePDFRenderer().render(content)
        let document = try #require(PDFDocument(data: data))
        let page = try #require(document.page(at: 0))

        #expect(data.starts(with: Data("%PDF".utf8)))
        #expect(page.bounds(for: .mediaBox).size == CGSize(width: 456, height: 792))
    }

    @Test func rendersAllSnapshotFieldsAndOptionalFieldsWhenPresent() throws {
        let content = InvoicePDFContent(
            number: "0001", invoiceDate: Date(timeIntervalSinceReferenceDate: 1_000), dueDate: Date(timeIntervalSinceReferenceDate: 2_000), status: .paid, payment: .init(amountMinorUnits: 12_500, receivedAt: Date(timeIntervalSinceReferenceDate: 3_000), method: .bankTransfer, otherDescription: nil, reference: "BANK-42"), currencyCode: "USD", businessName: "Farrier Name", businessPhone: "555-0100", businessEmail: "farrier@example.com", businessAddress: "1 Long Street", clientName: "Client Name", clientPhone: "555-0101", clientEmail: "client@example.com", visits: [.init(date: .now, location: "North Field", address: "25 Stable Lane", lineItems: [.init(horseName: "Milo", serviceName: "Full Set", amountMinorUnits: 12_500)])], totalMinorUnits: 12_500, note: "Thank you for your business."
        )
        let data = try InvoicePDFRenderer().render(content)
        let document = try #require(PDFDocument(data: data))
        let text = document.string ?? ""
        for expected in [
            "Invoice 0001",
            Date(timeIntervalSinceReferenceDate: 1_000).formatted(date: .abbreviated, time: .omitted),
            Date(timeIntervalSinceReferenceDate: 2_000).formatted(date: .abbreviated, time: .omitted),
            Date(timeIntervalSinceReferenceDate: 3_000).formatted(date: .abbreviated, time: .omitted),
            "Farrier Name",
            "555-0100",
            "farrier@example.com",
            "1 Long Street",
            "Client Name",
            "555-0101",
            "client@example.com",
            "Paid",
            "Bank Transfer",
            "BANK-42",
            "North Field",
            "25 Stable Lane",
            "Milo",
            "Full Set",
            "$125.00",
            "Invoice Total",
            "Total",
            "Thank you for your business.",
        ] {
            #expect(text.contains(expected))
        }
    }

    @Test func omitsAbsentOptionalSnapshotFields() throws {
        let content = InvoicePDFContent(number: "0001", invoiceDate: .now, dueDate: nil, status: .unpaid, payment: nil, currencyCode: "USD", businessName: "Farrier", businessPhone: nil, businessEmail: nil, businessAddress: nil, clientName: "Client", clientPhone: nil, clientEmail: nil, visits: [], totalMinorUnits: 0, note: nil)
        let document = try #require(PDFDocument(data: InvoicePDFRenderer().render(content)))
        let text = document.string ?? ""

        #expect(text.contains("Unpaid"))
        #expect(!text.contains("Due Date"))
        #expect(!text.contains("Payment Date"))
        #expect(!text.contains("Note"))
    }

    @Test func paginatesLargeInvoicesAcrossNarrowPages() throws {
        let lines = (0..<180).map { InvoicePDFContent.LineItem(horseName: "Horse \($0)", serviceName: "Full Set", amountMinorUnits: 12_500) }
        let content = InvoicePDFContent(number: "0001", invoiceDate: .now, dueDate: nil, status: .unpaid, payment: nil, currencyCode: "USD", businessName: "Farrier", businessPhone: nil, businessEmail: nil, businessAddress: nil, clientName: "Client", clientPhone: nil, clientEmail: nil, visits: [.init(date: .now, location: "North Field", address: nil, lineItems: lines)], totalMinorUnits: 2_250_000, note: String(repeating: "Long note. ", count: 80))
        let data = try InvoicePDFRenderer().render(content)
        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount > 1)
        for pageIndex in 0..<document.pageCount {
            let page = try #require(document.page(at: pageIndex))
            #expect(page.bounds(for: .mediaBox).size == CGSize(width: 456, height: 792))
            let pageText = page.string ?? ""
            if pageText.contains("Horse ") {
                #expect(pageText.contains("North Field"))
            }
        }
        #expect(document.page(at: document.pageCount - 1)?.string?.contains("Amount Due") == true)
    }

    @Test func preservesLongNarrowDocumentValues() throws {
        let content = InvoicePDFContent(
            number: "0148",
            invoiceDate: .now,
            dueDate: .now,
            status: .unpaid,
            payment: nil,
            currencyCode: "USD",
            businessName: "Carter Farrier Service and Hoof Care",
            businessPhone: nil,
            businessEmail: nil,
            businessAddress: "1847 Old County Road, Building Four, Lexington, Kentucky",
            clientName: "Alexandria Montgomery-Wellington",
            clientPhone: nil,
            clientEmail: nil,
            visits: [
                .init(
                    date: .now,
                    location: "Cedar Ridge Equestrian Training and Rehabilitation Center",
                    address: "925 Thoroughbred Lane, North Training Complex, Lexington, Kentucky",
                    lineItems: [
                        .init(
                            horseName: "Sir Montgomery of Willow Creek",
                            serviceName: "Therapeutic Trim and Hoof Balance Assessment with Corrective Shoeing",
                            amountMinorUnits: 18_975
                        ),
                    ]
                ),
            ],
            totalMinorUnits: 18_975,
            note: nil
        )

        let document = try #require(PDFDocument(data: InvoicePDFRenderer().render(content)))
        let text = document.string ?? ""
        let normalizedText = text.split(whereSeparator: \.isWhitespace).joined(separator: " ")

        for expected in [
            "Alexandria Montgomery-Wellington",
            "Cedar Ridge Equestrian Training and Rehabilitation Center",
            "Sir Montgomery of Willow Creek",
            "Therapeutic Trim and Hoof Balance Assessment with Corrective Shoeing",
            "$189.75",
        ] {
            #expect(normalizedText.contains(expected))
        }
    }

    @Test func paginatesOneOversizedTextBlockWithoutLosingText() throws {
        let markers = (0..<220).map { "OVERSIZED-NOTE-MARKER-\($0)" }
        let content = InvoicePDFContent(
            number: "0001",
            invoiceDate: .now,
            dueDate: nil,
            status: .unpaid,
            payment: nil,
            currencyCode: "USD",
            businessName: "Farrier",
            businessPhone: nil,
            businessEmail: nil,
            businessAddress: nil,
            clientName: "Client",
            clientPhone: nil,
            clientEmail: nil,
            visits: [],
            totalMinorUnits: 0,
            note: markers.joined(separator: "\n")
        )

        let document = try #require(PDFDocument(data: InvoicePDFRenderer().render(content)))
        let text = document.string ?? ""

        #expect(document.pageCount > 1)
        for marker in markers {
            #expect(text.contains(marker))
        }
    }
}
