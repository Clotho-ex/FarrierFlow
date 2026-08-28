import Foundation
import Testing

@Suite("Invoice payment mutation boundary")
struct InvoicePaymentMutationBoundaryTests {
    @Test
    func productionCallersCannotBypassPaymentUseCase() throws {
        let files = try swiftSources()
        let aggregatePath = "Core/Persistence/Schema/Invoice.swift"
        let useCasePath = "Features/Invoices/InvoicePaymentUseCase.swift"

        for (path, source) in files {
            if path != aggregatePath {
                let assignsStatus = source.split(separator: "\n").contains {
                    $0.contains("statusRawValue =") && !$0.contains("statusRawValue ==")
                }
                #expect(!assignsStatus, "Unauthorized status mutation in \(path)")
                #expect(!source.contains("payments.append("), "Unauthorized payment append in \(path)")
                #expect(!source.contains("payments.removeAll("), "Unauthorized payment removal in \(path)")
            }
            if path != aggregatePath, path != useCasePath {
                #expect(!source.contains("recordCompletedPayment("), "Unauthorized paid transition in \(path)")
                #expect(!source.contains("removeCompletedPayment("), "Unauthorized unpaid transition in \(path)")
            }
        }

        let invoice = try #require(files[aggregatePath])
        #expect(invoice.contains("private(set) var statusRawValue"))
        #expect(invoice.contains("private(set) var payments"))
    }

    private func swiftSources() throws -> [String: String] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "FarrierFlow", directoryHint: .isDirectory)
        let enumerator = try #require(FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        ))
        var sources: [String: String] = [:]
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let path = String(file.path.dropFirst(root.path.count + 1))
            sources[path] = try String(contentsOf: file, encoding: .utf8)
        }
        return sources
    }
}
