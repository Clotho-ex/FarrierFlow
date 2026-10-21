import Foundation
import Testing

@Suite("Invoice payment mutation boundary")
struct InvoicePaymentMutationBoundaryTests {
    @Test
    func openPaymentSheetRequiresLiveSubscriptionAccessToConfirm() throws {
        let files = try swiftSources()
        let invoiceDetail = try #require(
            files["Features/Invoices/Views/InvoiceDetailView.swift"]
        )
        let paymentAndFollowingViews = try #require(
            invoiceDetail
                .split(separator: "private struct PaymentRecordingView", maxSplits: 1)
                .last
        )
        let paymentView = try #require(
            paymentAndFollowingViews
                .split(separator: "private struct InvoiceContactSection", maxSplits: 1)
                .first
        )
        let compactSource = paymentView.filter { !$0.isWhitespace }

        #expect(
            compactSource.contains(
                "@Environment(SubscriptionAccessModel.self)privatevarsubscription"
            )
        )
        #expect(
            compactSource.contains(
                "guardsubscription.allowsMutationselse{return}"
            )
        )
        #expect(
            compactSource.contains(
                ".disabled(!subscription.allowsMutations||!model.canConfirm)"
            )
        )
    }

    @Test
    func productionCallersCannotBypassPaymentUseCase() throws {
        let files = try swiftSources()
        let aggregatePath = "Core/Persistence/Schema/Invoice.swift"
        let useCasePath = "Features/Invoices/InvoicePaymentUseCase.swift"
        let restorePath = "Features/BackupSync/SyncGraphCodec.swift"
        let deletionPath = "Core/Persistence/RecordDeletionPlan.swift"

        for (path, source) in files {
            if path.hasPrefix("Core/Persistence/Migrations/") {
                continue
            }
            if path != aggregatePath {
                let assignsStatus = source.split(separator: "\n").contains {
                    $0.contains("statusRawValue =") && !$0.contains("statusRawValue ==")
                }
                #expect(!assignsStatus, "Unauthorized status mutation in \(path)")
                #expect(!source.contains("payments.append("), "Unauthorized payment append in \(path)")
                #expect(!source.contains("payments.removeAll("), "Unauthorized payment removal in \(path)")
            }
            // A complete validated cloud/history restore uses the same aggregate
            // transitions, without invoking an independently saving UI use case.
            if path != aggregatePath, path != useCasePath, path != restorePath {
                #expect(!source.contains("recordCompletedPayment("), "Unauthorized paid transition in \(path)")
                // Explicit Invoice deletion removes its Payment through the same
                // aggregate transition before atomically deleting the Invoice.
                if path != deletionPath {
                    #expect(!source.contains("removeCompletedPayment("), "Unauthorized unpaid transition in \(path)")
                }
            }
        }

        let invoice = try #require(files[aggregatePath])
        #expect(invoice.contains("private(set) var statusRawValue"))
        #expect(invoice.contains("private(set) var payments"))
        let restore = try #require(files[restorePath])
        #expect(restore.contains("try DomainGraphValidator.validateAll(in: validationStore.mainContext)"))
        #expect(restore.contains("context.rollback()"))
    }

    private func swiftSources() throws -> [String: String] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "FarrierFlow", directoryHint: .isDirectory)
            .resolvingSymlinksInPath()
        let enumerator = try #require(FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        ))
        var sources: [String: String] = [:]
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let path = String(file.resolvingSymlinksInPath().path.dropFirst(root.path.count + 1))
            sources[path] = try String(contentsOf: file, encoding: .utf8)
        }
        return sources
    }
}
