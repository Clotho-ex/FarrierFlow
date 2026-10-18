import Foundation
import Supabase
import Testing
@testable import FarrierFlow

@Suite("Official SDK sync transport", .serialized)
struct SupabaseSyncTransportTests {
    @Test
    func versionedPushUsesExactOriginalPayloadAndSelectedContract() async throws {
        let record = SyncRecord(id: UUID(), kind: .workItem,
            fields: ["billingHoldID": .string(UUID().uuidString.lowercased()),
                     "amountMinorUnits": .integer(9_007_199_254_740_993)])
        let batch = SyncBatch(operationID: UUID(), workspaceID: UUID(), deviceID: UUID(),
            invoicingGeneration: 3, mutations: [.init(id: record.id, kind: .workItem,
                expectedRevision: 4, record: record)])
        SyncHTTPStub.configure { request in
            #expect(request.url?.path == "/rest/v1/rpc/ff_sync_push_v2")
            let body = try JSONDecoder().decode(PushBody.self, from: SyncHTTPStub.body(of: request))
            #expect(body.p_batch == batch)
            return (200, Data("{\"operationID\":\"\(batch.operationID)\",\"revision\":5}".utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        let result = try await makeTransport().push(batch, protocolVersion: .holds)
        #expect(result.operationID == batch.operationID && result.revision == 5)
    }

    @Test
    func explicitBillingRejectionIsNotAnAmbiguousNetworkFailure() async throws {
        let batch = SyncBatch(operationID: UUID(), workspaceID: UUID(), deviceID: UUID(),
            invoicingGeneration: 1, mutations: [])
        SyncHTTPStub.configure { _ in
            (400, Data("{\"code\":\"P0001\",\"message\":\"FF_ALREADY_BILLED\",\"details\":null,\"hint\":null}".utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        let transport = try makeTransport()
        await #expect(throws: SyncTransportError.confirmedRejection(.alreadyBilled)) {
            try await transport.push(batch, protocolVersion: .holds)
        }
    }

    @Test
    func bootstrapSendsDeviceIdentityAndUsesAuthenticatedSDKRequest() async throws {
        let device = UUID()
        let workspace = UUID()
        SyncHTTPStub.configure { request in
            #expect(request.url?.path == "/rest/v1/rpc/ff_sync_bootstrap_v2")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-session-token")
            let body = try JSONDecoder().decode(
                BootstrapBody.self, from: SyncHTTPStub.body(of: request)
            )
            #expect(body.p_device == device)
            return (200, Data("""
            {"workspaceID":"\(workspace)","deviceID":"\(device)","invoicingDeviceID":"\(device)","invoicingGeneration":1,"revision":0}
            """.utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        let transport = try makeTransport()
        let info = try await transport.bootstrap(deviceID: device)
        #expect(info.workspaceID == workspace)
        #expect(info.invoicingDeviceID == device)
    }

    @Test
    func pushPreservesExactLargeMinorUnitAmountAndOperationIdentity() async throws {
        let operation = UUID()
        let workspace = UUID()
        let record = SyncRecord(id: UUID(), kind: .workItem,
                                fields: ["amountMinorUnits": .integer(9_007_199_254_740_993)])
        let batch = SyncBatch(
            operationID: operation, workspaceID: workspace, deviceID: UUID(),
            invoicingGeneration: 1,
            mutations: [.init(id: record.id, kind: .workItem, expectedRevision: 4, record: record)]
        )
        SyncHTTPStub.configure { request in
            #expect(request.url?.path == "/rest/v1/rpc/ff_sync_push")
            let body = try JSONDecoder().decode(PushBody.self, from: SyncHTTPStub.body(of: request))
            #expect(body.p_batch.operationID == operation)
            #expect(body.p_batch.mutations.first?.record?.fields["amountMinorUnits"] ==
                    .integer(9_007_199_254_740_993))
            return (200, Data("""
            {"operationID":"\(operation)","revision":5}
            """.utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        let receipt = try await makeTransport().push(batch)
        #expect(receipt.revision == 5)
    }

    @Test
    func forgedReceiptCannotAcknowledgeAnotherOperation() async throws {
        let batch = SyncBatch(
            operationID: UUID(), workspaceID: UUID(), deviceID: UUID(),
            invoicingGeneration: 1, mutations: []
        )
        SyncHTTPStub.configure { _ in
            (200, Data("""
            {"operationID":"\(UUID())","revision":1}
            """.utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        let transport = try makeTransport()
        await #expect(throws: SyncTransportError.invalidResponse) {
            try await transport.push(batch)
        }
    }

    @Test
    func pullRejectsForeignWorkspaceEvenIfItHasAValidLookingCursor() async throws {
        let workspace = UUID()
        SyncHTTPStub.configure { _ in
            (200, Data("""
            {"workspaceID":"\(UUID())","cursor":0,"hasMore":false,"transactions":[],"invoicingDeviceID":null,"invoicingGeneration":1}
            """.utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        let transport = try makeTransport()
        await #expect(throws: SyncTransportError.invalidResponse) {
            try await transport.pull(workspaceID: workspace, cursor: 0)
        }
    }

    @Test
    func pullCannotSkipACommitOrClaimMoreWithNoProgress() async throws {
        let workspace = UUID()
        SyncHTTPStub.configure { _ in
            (200, Data("""
            {"workspaceID":"\(workspace)","cursor":2,"hasMore":false,"transactions":[{"workspaceID":"\(workspace)","revision":2,"mutations":[]}],"invoicingDeviceID":null,"invoicingGeneration":1}
            """.utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        let transport = try makeTransport()
        await #expect(throws: SyncTransportError.invalidResponse) {
            try await transport.pull(workspaceID: workspace, cursor: 0)
        }
    }

    @Test
    func explicitServerRevisionRejectionIsDistinguishedFromUnknownNetworkOutcome() async throws {
        let batch = SyncBatch(operationID: UUID(), workspaceID: UUID(), deviceID: UUID(),
                              invoicingGeneration: 1, mutations: [])
        SyncHTTPStub.configure { _ in
            (409, Data("""
            {"code":"40001","message":"Record revision conflict","details":null,"hint":null}
            """.utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        let transport = try makeTransport()
        await #expect(throws: SyncTransportError.revisionConflict) {
            try await transport.push(batch)
        }
    }

    @Test
    func takeoverUsesAuthenticatedWorkspaceDeviceAndExpectedGeneration() async throws {
        let workspace = UUID(), device = UUID()
        SyncHTTPStub.configure { request in
            #expect(request.url?.path == "/rest/v1/rpc/ff_invoicing_takeover")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-session-token")
            let body = try JSONDecoder().decode(TakeoverBody.self, from: SyncHTTPStub.body(of: request))
            #expect(body.p_workspace == workspace && body.p_device == device && body.p_generation == 3)
            return (200, Data("""
            {"invoicingDeviceID":"\(device)","invoicingGeneration":4,"revision":12}
            """.utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        let result = try await makeTransport().takeOverInvoicing(workspaceID: workspace, deviceID: device, generation: 3)
        #expect(result.invoicingGeneration == 4 && result.revision == 12)
    }

    @Test
    func takeoverRejectsForgedDeviceReceiptAndStaleGenerationIsExplicitRollback() async throws {
        let workspace = UUID(), device = UUID()
        SyncHTTPStub.configure { _ in (200, Data("""
        {"invoicingDeviceID":"\(UUID())","invoicingGeneration":4,"revision":12}
        """.utf8)) }
        defer { SyncHTTPStub.configure(nil) }
        let transport = try makeTransport()
        await #expect(throws: SyncTransportError.invalidResponse) {
            try await transport.takeOverInvoicing(workspaceID: workspace, deviceID: device, generation: 3)
        }
        SyncHTTPStub.configure { _ in (409, Data("""
        {"code":"40001","message":"Invoicing generation changed","details":null,"hint":null}
        """.utf8)) }
        await #expect(throws: SyncTransportError.revisionConflict) {
            try await transport.takeOverInvoicing(workspaceID: workspace, deviceID: device, generation: 3)
        }
    }

    @Test
    func onlyExactDesignatedDeviceDenialIsAConfirmedInvoiceRejection() async throws {
        let batch = SyncBatch(operationID: UUID(), workspaceID: UUID(), deviceID: UUID(), invoicingGeneration: 1, mutations: [])
        SyncHTTPStub.configure { _ in (403, Data("""
        {"code":"42501","message":"Designated invoicing device required","details":null,"hint":null}
        """.utf8)) }
        defer { SyncHTTPStub.configure(nil) }
        let transport = try makeTransport()
        await #expect(throws: SyncTransportError.invoicingDeviceRejected) { try await transport.push(batch) }
        SyncHTTPStub.configure { _ in (403, Data("""
        {"code":"42501","message":"Workspace access denied","details":null,"hint":null}
        """.utf8)) }
        await #expect(throws: PostgrestError.self) { try await transport.push(batch) }
    }

    private func makeTransport() throws -> SupabaseSyncTransport {
        let url = try #require(URL(string: "https://sync-test.supabase.co"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SyncHTTPStub.self]
        let session = URLSession(configuration: configuration)
        let client = SupabaseClient(
            supabaseURL: url, supabaseKey: "sb_publishable_test_only",
            options: .init(
                auth: .init(storage: SyncTestAuthStorage(), autoRefreshToken: false,
                            accessToken: { "test-session-token" }),
                global: .init(session: session)
            )
        )
        return SupabaseSyncTransport(client: client)
    }

    private struct BootstrapBody: Decodable { let p_device: UUID }
    private struct PushBody: Decodable { let p_batch: SyncBatch }
    private struct TakeoverBody: Decodable { let p_workspace: UUID; let p_device: UUID; let p_generation: Int64 }
}
