import Foundation
import Supabase
import Testing
@testable import FarrierFlow

@Suite("Private photo SDK transport", .serialized)
struct SupabasePhotoTransportTests {
    @Test
    func uploadUsesWorkspacePathCanonicalJPEGAndNeverUpserts() async throws {
        let workspace = UUID()
        let payload = try makePayload()
        let path = "\(workspace.uuidString.lowercased())/\(payload.id.uuidString.lowercased()).jpg"
        SyncHTTPStub.configure { request in
            #expect(request.url?.path == "/storage/v1/object/farrierflow-photos/\(path)")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-session-token")
            #expect(request.value(forHTTPHeaderField: "x-upsert") == "false")
            let body = try SyncHTTPStub.body(of: request)
            #expect(body.range(of: payload.data) != nil)
            #expect(body.range(of: Data("image/jpeg".utf8)) != nil)
            return (200, Data("{\"Id\":\"\(UUID())\",\"Key\":\"farrierflow-photos/\(path)\"}".utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        try await makeTransport().upload(workspaceID: workspace, payload: payload)
    }

    @Test
    func downloadUsesAuthenticatedObjectNotPublicOrTransformedURL() async throws {
        let workspace = UUID()
        let payload = try makePayload()
        let path = "\(workspace.uuidString.lowercased())/\(payload.id.uuidString.lowercased()).jpg"
        SyncHTTPStub.configure { request in
            #expect(request.url?.path == "/storage/v1/object/farrierflow-photos/\(path)")
            #expect(request.httpMethod == "GET")
            #expect(request.url?.query == nil)
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-session-token")
            return (200, payload.data)
        }
        defer { SyncHTTPStub.configure(nil) }
        let downloaded = try await makeTransport().download(workspaceID: workspace, photoID: payload.id)
        #expect(downloaded == payload.data)
    }

    @Test
    func commitReceiptMustMatchExactPhotoDigestSizeAndIdentity() async throws {
        let payload = try makePayload()
        let workspace = UUID()
        SyncHTTPStub.configure { request in
            #expect(request.url?.path == "/rest/v1/rpc/ff_photo_commit")
            let body = try JSONDecoder().decode(CommitBody.self, from: SyncHTTPStub.body(of: request))
            #expect(body.p_workspace == workspace)
            #expect(body.p_photo == payload.id)
            #expect(body.p_digest == payload.digest)
            return (200, Self.manifestData(payload: payload))
        }
        defer { SyncHTTPStub.configure(nil) }
        let entry = try await makeTransport().commit(workspaceID: workspace, payload: payload)
        #expect(entry.id == payload.id)
        #expect(entry.digest == payload.digest)
    }

    @Test
    func forgedPhotoReceiptCannotMarkOriginalProtected() async throws {
        let payload = try makePayload()
        SyncHTTPStub.configure { _ in
            (200, Self.manifestData(payload: payload, id: UUID()))
        }
        defer { SyncHTTPStub.configure(nil) }
        let transport = try makeTransport()
        await #expect(throws: SyncTransportError.invalidResponse) {
            try await transport.commit(workspaceID: UUID(), payload: payload)
        }
    }

    @Test
    func duplicateManifestIdentitiesAreRejected() async throws {
        let payload = try makePayload()
        let entry = Self.manifestData(payload: payload)
        SyncHTTPStub.configure { _ in
            (200, Data("[".utf8) + entry + Data(",".utf8) + entry + Data("]".utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        let transport = try makeTransport()
        await #expect(throws: SyncTransportError.invalidResponse) {
            try await transport.manifest(workspaceID: UUID())
        }
    }

    private func makePayload() throws -> SyncPhotoPayload {
        let data = try PhotographTestFixtures.jpeg()
        return try SyncPhotoPayload.validate(data: data, record: .init(
            id: UUID(), kind: .photograph, fields: ["byteCount": .integer(Int64(data.count)),
                "pixelWidth": .integer(80), "pixelHeight": .integer(60)]
        ))
    }

    @Test
    func deletionUsesExactPrivatePathAndRequiresServerConfirmation() async throws {
        let workspace = UUID()
        let photo = UUID()
        let path = "\(workspace.uuidString.lowercased())/\(photo.uuidString.lowercased()).jpg"
        SyncHTTPStub.configure { request in
            if request.httpMethod == "DELETE" {
                #expect(request.url?.path == "/storage/v1/object/farrierflow-photos")
                let body = try JSONDecoder().decode(DeleteBody.self, from: SyncHTTPStub.body(of: request))
                #expect(body.prefixes == [path])
                return (200, Data("[]".utf8))
            }
            #expect(request.url?.path == "/rest/v1/rpc/ff_photo_delete_confirm")
            let body = try JSONDecoder().decode(DeleteConfirmationBody.self, from: SyncHTTPStub.body(of: request))
            #expect(body.p_workspace == workspace)
            #expect(body.p_photo == photo)
            return (200, Data("{\"id\":\"\(photo)\",\"deleted\":true}".utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        try await makeTransport().delete(workspaceID: workspace, photoID: photo)
    }

    @Test
    func deletionCannotAcceptAnotherPhotoReceipt() async throws {
        SyncHTTPStub.configure { request in
            if request.httpMethod == "DELETE" { return (200, Data("[]".utf8)) }
            return (200, Data("{\"id\":\"\(UUID())\",\"deleted\":true}".utf8))
        }
        defer { SyncHTTPStub.configure(nil) }
        await #expect(throws: SyncTransportError.invalidResponse) {
            try await makeTransport().delete(workspaceID: UUID(), photoID: UUID())
        }
    }

    private nonisolated struct DeleteBody: Decodable { let prefixes: [String] }
    private nonisolated struct DeleteConfirmationBody: Decodable {
        let p_workspace: UUID
        let p_photo: UUID
    }

    private func makeTransport() throws -> SupabasePhotoTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SyncHTTPStub.self]
        return SupabasePhotoTransport(client: SupabaseClient(
            supabaseURL: try #require(URL(string: "https://photo-test.supabase.co")),
            supabaseKey: "sb_publishable_test_only",
            options: .init(auth: .init(storage: SyncTestAuthStorage(), autoRefreshToken: false,
                                      accessToken: { "test-session-token" }),
                           global: .init(session: URLSession(configuration: configuration)))
        ))
    }

    private nonisolated static func manifestData(payload: SyncPhotoPayload, id: UUID? = nil) -> Data {
        Data("{\"id\":\"\(id ?? payload.id)\",\"digest\":\"\(payload.digest)\",\"byteCount\":\(payload.data.count)}".utf8)
    }
    private nonisolated struct CommitBody: Decodable {
        let p_workspace: UUID
        let p_photo: UUID
        let p_digest: String
    }
}
