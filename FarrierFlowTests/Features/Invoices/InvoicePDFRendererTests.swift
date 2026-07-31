import Foundation
import PDFKit
import Testing
@testable import FarrierFlow

@Suite("Invoice PDF renderer", .serialized)
struct InvoicePDFRendererTests {
    @Test func rendersUSLetterPDF() throws {
        let content = InvoicePDFContent(number: "0001", invoiceDate: .now, dueDate: nil, status: .unpaid, paidAt: nil, businessName: "Farrier", businessPhone: nil, businessEmail: nil, businessAddress: nil, clientName: "Client", clientPhone: nil, clientEmail: nil, visits: [], totalMinorUnits: 0, note: nil)
        let data = try InvoicePDFRenderer().render(content)
        let document = try #require(PDFDocument(data: data))
        let page = try #require(document.page(at: 0))

        #expect(data.starts(with: Data("%PDF".utf8)))
        #expect(page.bounds(for: .mediaBox).size == CGSize(width: 612, height: 792))
    }

    @Test func rendersAllSnapshotFieldsAndOptionalFieldsWhenPresent() throws {
        let content = InvoicePDFContent(
            number: "0001", invoiceDate: Date(timeIntervalSinceReferenceDate: 1_000), dueDate: Date(timeIntervalSinceReferenceDate: 2_000), status: .paid, paidAt: Date(timeIntervalSinceReferenceDate: 3_000), businessName: "Farrier Name", businessPhone: "555-0100", businessEmail: "farrier@example.com", businessAddress: "1 Long Street", clientName: "Client Name", clientPhone: "555-0101", clientEmail: "client@example.com", visits: [.init(date: .now, location: "North Field", address: "25 Stable Lane", lineItems: [.init(horseName: "Milo", serviceName: "Full Set", amountMinorUnits: 12_500)])], totalMinorUnits: 12_500, note: "Thank you for your business."
        )
        let document = try #require(PDFDocument(data: InvoicePDFRenderer().render(content)))
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
            "North Field",
            "25 Stable Lane",
            "Milo",
            "Full Set",
            try #require(MoneyFormatter.usd(minorUnits: 12_500)),
            "Total",
            "Thank you for your business.",
        ] {
            #expect(text.contains(expected))
        }
    }

    @Test func omitsAbsentOptionalSnapshotFields() throws {
        let content = InvoicePDFContent(number: "0001", invoiceDate: .now, dueDate: nil, status: .unpaid, paidAt: nil, businessName: "Farrier", businessPhone: nil, businessEmail: nil, businessAddress: nil, clientName: "Client", clientPhone: nil, clientEmail: nil, visits: [], totalMinorUnits: 0, note: nil)
        let document = try #require(PDFDocument(data: InvoicePDFRenderer().render(content)))
        let text = document.string ?? ""

        #expect(text.contains("Unpaid"))
        #expect(!text.contains("Due Date"))
        #expect(!text.contains("Payment Date"))
        #expect(!text.contains("Note"))
    }

    @Test func paginatesLargeInvoicesAcrossUSLetterPages() throws {
        let lines = (0..<180).map { InvoicePDFContent.LineItem(horseName: "Horse \($0)", serviceName: "Full Set", amountMinorUnits: 12_500) }
        let content = InvoicePDFContent(number: "0001", invoiceDate: .now, dueDate: nil, status: .unpaid, paidAt: nil, businessName: "Farrier", businessPhone: nil, businessEmail: nil, businessAddress: nil, clientName: "Client", clientPhone: nil, clientEmail: nil, visits: [.init(date: .now, location: "North Field", address: nil, lineItems: lines)], totalMinorUnits: 2_250_000, note: String(repeating: "Long note. ", count: 80))
        let document = try #require(PDFDocument(data: InvoicePDFRenderer().render(content)))
        #expect(document.pageCount > 1)
        for pageIndex in 0..<document.pageCount {
            #expect(document.page(at: pageIndex)?.bounds(for: .mediaBox).size == CGSize(width: 612, height: 792))
        }
        #expect(document.page(at: document.pageCount - 1)?.string?.contains("Total") == true)
    }

    @Test func paginatesOneOversizedTextBlockWithoutLosingText() throws {
        let markers = (0..<220).map { "OVERSIZED-NOTE-MARKER-\($0)" }
        let content = InvoicePDFContent(
            number: "0001",
            invoiceDate: .now,
            dueDate: nil,
            status: .unpaid,
            paidAt: nil,
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
