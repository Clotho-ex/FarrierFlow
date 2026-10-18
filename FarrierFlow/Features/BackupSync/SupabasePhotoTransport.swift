import Foundation
import Supabase

nonisolated struct SyncPhotoManifestEntry: Codable, Equatable, Sendable {
    let id: UUID
    let digest: String
    let byteCount: Int64

    var isValid: Bool {
        byteCount > 0 && byteCount <= 20 * 1_024 * 1_024 &&
        digest.utf8.count == 64 && digest.utf8.allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }
}

nonisolated protocol SyncPhotoTransport: Sendable {
    func manifest(workspaceID: UUID) async throws -> [SyncPhotoManifestEntry]
    func upload(workspaceID: UUID, payload: SyncPhotoPayload) async throws
    func download(workspaceID: UUID, photoID: UUID) async throws -> Data
    func commit(workspaceID: UUID, payload: SyncPhotoPayload) async throws -> SyncPhotoManifestEntry
    func delete(workspaceID: UUID, photoID: UUID) async throws
}

nonisolated struct SupabasePhotoTransport: SyncPhotoTransport {
    let client: SupabaseClient
    private static let bucket = "farrierflow-photos"

    func manifest(workspaceID: UUID) async throws -> [SyncPhotoManifestEntry] {
        let entries: [SyncPhotoManifestEntry] = try await client
            .rpc("ff_photo_list", params: WorkspaceParameters(p_workspace: workspaceID))
            .execute().value
        var seen = Set<UUID>()
        for entry in entries {
            guard seen.insert(entry.id).inserted, entry.isValid else {
                throw SyncTransportError.invalidResponse
            }
        }
        return entries
    }
    func upload(workspaceID: UUID, payload: SyncPhotoPayload) async throws {
        let path = Self.path(workspaceID: workspaceID, photoID: payload.id)
        let receipt = try await client.storage.from(Self.bucket).upload(
            path, data: payload.data,
            options: FileOptions(cacheControl: "0", contentType: "image/jpeg", upsert: false)
        )
        guard receipt.fullPath == "\(Self.bucket)/\(path)", UUID(uuidString: receipt.id) != nil else {
            throw SyncTransportError.invalidResponse
        }
    }
    func download(workspaceID: UUID, photoID: UUID) async throws -> Data {
        try await client.storage.from(Self.bucket).download(
            path: Self.path(workspaceID: workspaceID, photoID: photoID)
        )
    }
    func commit(workspaceID: UUID, payload: SyncPhotoPayload) async throws -> SyncPhotoManifestEntry {
        let entry: SyncPhotoManifestEntry = try await client
            .rpc("ff_photo_commit", params: CommitParameters(
                p_workspace: workspaceID, p_photo: payload.id, p_digest: payload.digest
            )).execute().value
        guard entry.isValid, entry.id == payload.id, entry.digest == payload.digest,
              entry.byteCount == Int64(payload.data.count) else {
            throw SyncTransportError.invalidResponse
        }
        return entry
    }

    func delete(workspaceID: UUID, photoID: UUID) async throws {
        try Task.checkCancellation()
        _ = try await client.storage.from(Self.bucket).remove(
            paths: [Self.path(workspaceID: workspaceID, photoID: photoID)]
        )
        try Task.checkCancellation()
        // Storage may return an empty success for an absent or filtered object.
        // Only the authorized server check can confirm the bytes are gone.
        let receipt: DeletionReceipt = try await client
            .rpc("ff_photo_delete_confirm", params: DeletionParameters(
                p_workspace: workspaceID, p_photo: photoID
            )).execute().value
        try Task.checkCancellation()
        guard receipt.id == photoID, receipt.deleted else {
            throw SyncTransportError.invalidResponse
        }
    }

    private static func path(workspaceID: UUID, photoID: UUID) -> String {
        "\(workspaceID.uuidString.lowercased())/\(photoID.uuidString.lowercased()).jpg"
    }

    private struct WorkspaceParameters: Encodable { let p_workspace: UUID }
    private struct CommitParameters: Encodable {
        let p_workspace: UUID
        let p_photo: UUID
        let p_digest: String
    }
    private struct DeletionParameters: Encodable {
        let p_workspace: UUID
        let p_photo: UUID
    }
    private struct DeletionReceipt: Decodable {
        let id: UUID
        let deleted: Bool
    }
}
