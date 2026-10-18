import Foundation
import Supabase
import Testing
@testable import FarrierFlow

@Suite("Confirmed cloud deletion requests", .serialized)
struct CloudDeletionTransportTests {
    @Test
    func requestUsesFreshAppleProofAndOpaqueReceiptWithoutSendingAnAccountID() async throws {
        let intent = try CloudDeletionIntent(accountID: UUID(), workspaceID: UUID())
        let challenge = try AppleSignInChallenge()
        SyncHTTPStub.configure { request in
            #expect(request.url?.path == "/functions/v1/delete-cloud-account/request")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-session-token")
            let body = try JSONDecoder().decode(RequestBody.self, from: SyncHTTPStub.body(of: request))
            #expect(body.workspaceID == intent.workspaceID && body.operationID == intent.operationID)
            #expect(body.receiptToken == intent.receiptToken && body.nonce == challenge.rawNonce)
            #expect(body.identityToken == "fresh-apple-token" && body.authorizationCode == "fresh-apple-code")
            let raw = try #require(String(data: SyncHTTPStub.body(of: request), encoding: .utf8))
            #expect(!raw.contains("accountID"))
            return (202, Data("""
            {"state":"pending","jobID":"\(intent.operationID)"}
            """.utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        let result = try await makeTransport().request(intent, identityToken: Data("fresh-apple-token".utf8),
            authorizationCode: Data("fresh-apple-code".utf8), challenge: challenge)
        #expect(result == .pending(intent.operationID))
    }

    @Test
    func confirmationDoesNotRefreshOrRequireTheDeletedAuthSession() async throws {
        let intent = try CloudDeletionIntent(accountID: UUID(), workspaceID: UUID())
        SyncHTTPStub.configure { request in
            #expect(request.url?.path == "/functions/v1/delete-cloud-account/status")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_test_only")
            let body = try JSONDecoder().decode(StatusBody.self, from: SyncHTTPStub.body(of: request))
            #expect(body.operationID == intent.operationID && body.receiptToken == intent.receiptToken)
            #expect(request.url?.query == nil)
            return (200, Data("""
            {"state":"complete","jobID":"\(intent.operationID)"}
            """.utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        #expect(try await makeTransport().status(intent) == .complete(intent.operationID))
    }

    @Test
    func forgedCompletionAndUnverifiedQueueResponsesCannotConfirmDeletion() async throws {
        let intent = try CloudDeletionIntent(accountID: UUID(), workspaceID: UUID())
        SyncHTTPStub.configure { _ in (200, Data("""
        {"state":"complete","jobID":"\(UUID())"}
        """.utf8)) }
        defer { SyncHTTPStub.configure(nil) }
        let transport = try makeTransport()
        await #expect(throws: CloudDeletionError.invalidResponse) { try await transport.status(intent) }
        SyncHTTPStub.configure { _ in (200, Data("{\"state\":\"notFound\"}".utf8)) }
        await #expect(throws: CloudDeletionError.invalidResponse) {
            try await transport.request(intent, identityToken: Data("fresh-token".utf8),
                authorizationCode: Data("fresh-code".utf8), challenge: AppleSignInChallenge())
        }
    }

    private func makeTransport() throws -> SupabaseCloudDeletionTransport {
        let url = try #require(URL(string: "https://deletion-test.supabase.co"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SyncHTTPStub.self]
        let session = URLSession(configuration: configuration)
        let client = SupabaseClient(supabaseURL: url, supabaseKey: "sb_publishable_test_only",
            options: .init(auth: .init(storage: SyncTestAuthStorage(), autoRefreshToken: false,
                accessToken: { "test-session-token" }), global: .init(session: session)))
        let publicFunctions = FunctionsClient(url: url.appending(path: "functions/v1"),
            headers: ["apikey": "sb_publishable_test_only"], fetch: { try await session.data(for: $0) })
        return SupabaseCloudDeletionTransport(client: client, confirmation: publicFunctions)
    }
    private struct RequestBody: Decodable {
        let workspaceID: UUID; let operationID: UUID; let receiptToken: String
        let nonce: String; let identityToken: String; let authorizationCode: String
    }
    private struct StatusBody: Decodable { let operationID: UUID; let receiptToken: String }
}
