import Foundation
import Testing
@testable import FarrierFlow

@Suite("Invoice PDF temporary files", .serialized)
@MainActor
struct InvoicePDFTemporaryFileStoreTests {
    @Test func writesStableInvoiceFilenameAndRemovesIt() throws {
        let directory = try TemporaryStoreFixtures.makeDirectory(prefix: "FarrierFlow-PDF-")
        let store = InvoicePDFTemporaryFileStore(directory: directory)
        let url = try store.write(Data("pdf".utf8), number: "0001")
        #expect(url.lastPathComponent == "Invoice-0001.pdf")
        #expect(FileManager.default.fileExists(atPath: url.path))
        store.removeIfPresent(url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
}
