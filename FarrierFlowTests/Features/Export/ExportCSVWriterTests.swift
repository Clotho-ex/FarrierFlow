import Foundation
import Testing
@testable import FarrierFlow

@Suite("Export CSV writer")
struct ExportCSVWriterTests {
    @Test func encodesAHeaderOnlyTableUsingCRLF() throws {
        let table = ExportCSVTable(
            definition: .init(relativePath: "Data/clients.csv", columns: ["export_id", "name"]),
            rows: []
        )

        let output = try #require(String(data: ExportCSVWriter().encode(table), encoding: .utf8))

        #expect(output == "export_id,name\r\n")
    }

    @Test func escapesRFC4180CharactersAndPreservesUnicode() throws {
        let table = ExportCSVTable(
            definition: .init(relativePath: "Data/clients.csv", columns: ["text"]),
            rows: [[.userText("O\"Brien, LLC\r\nİstanbul")]]
        )

        let output = try #require(String(data: ExportCSVWriter().encode(table), encoding: .utf8))

        #expect(output == "text\r\n\"O\"\"Brien, LLC\r\nİstanbul\"\r\n")
    }

    @Test func encodesEmptyCellsAndNeutralizesOnlyFormulaRiskyUserText() throws {
        let table = ExportCSVTable(
            definition: .init(relativePath: "Data/clients.csv", columns: ["text"]),
            rows: [
                [.empty],
                [.userText("=2+2")], [.userText("  =2")], [.userText("  +2")], [.userText("  -2")], [.userText("  @x")], [.userText("\tsafe")], [.userText("\rsafe")], [.userText("\nsafe")], [.userText("\t-2")], [.userText("\r@x")], [.userText("\n=1")],
                [.userText("safe text")], [.raw("=raw")],
            ]
        )

        let output = try #require(String(data: ExportCSVWriter().encode(table), encoding: .utf8))

        #expect(output == "text\r\n\r\n'=2+2\r\n'  =2\r\n'  +2\r\n'  -2\r\n'  @x\r\n'\tsafe\r\n\"'\rsafe\"\r\n\"'\nsafe\"\r\n'\t-2\r\n\"'\r@x\"\r\n\"'\n=1\"\r\nsafe text\r\n=raw\r\n")
    }

    @Test func rejectsRowsWhoseWidthDoesNotMatchTheHeader() {
        let table = ExportCSVTable(
            definition: .init(relativePath: "Data/clients.csv", columns: ["export_id", "name"]),
            rows: [[.raw("client-000001")]]
        )

        #expect(throws: ExportFormatError.invalidRowWidth(relativePath: "Data/clients.csv", expected: 2, actual: 1)) {
            _ = try ExportCSVWriter().encode(table)
        }
    }
}
