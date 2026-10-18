import Foundation
import Supabase

nonisolated enum CloudDeletionStatus: Equatable, Sendable {
    case notFound, pending(UUID), complete(UUID)
}

nonisolated protocol CloudDeletionTransport: Sendable {
    func request(_ intent: CloudDeletionIntent, identityToken: Data, authorizationCode: Data,
                 challenge: AppleSignInChallenge) async throws -> CloudDeletionStatus
    func status(_ intent: CloudDeletionIntent) async throws -> CloudDeletionStatus
}

nonisolated struct SupabaseCloudDeletionTransport: CloudDeletionTransport {
    private let authenticated: @Sendable () async throws -> FunctionsClient
    let confirmation: FunctionsClient

    init(client: SupabaseClient, confirmation: FunctionsClient) {
        authenticated = { client.functions }
        self.confirmation = confirmation
    }
    init(authenticated: @escaping @Sendable () async throws -> FunctionsClient, confirmation: FunctionsClient) {
        self.authenticated = authenticated
        self.confirmation = confirmation
    }

    func request(_ intent: CloudDeletionIntent, identityToken: Data, authorizationCode: Data,
                 challenge: AppleSignInChallenge) async throws -> CloudDeletionStatus {
        guard intent.isValid, !identityToken.isEmpty, identityToken.count <= 16_384,
              !authorizationCode.isEmpty, authorizationCode.count <= 8_192,
              let token = String(data: identityToken, encoding: .utf8),
              let code = String(data: authorizationCode, encoding: .utf8) else {
            throw CloudDeletionError.invalidCredentials
        }
        try Task.checkCancellation()
        let functions = try await authenticated()
        try Task.checkCancellation()
        let result = try await functions.invoke("delete-cloud-account/request", options: .init(
            body: RequestBody(workspaceID: intent.workspaceID, operationID: intent.operationID,
                receiptToken: intent.receiptToken, nonce: challenge.rawNonce, identityToken: token, authorizationCode: code),
            timeoutInterval: 60
        )) { data, response in try Self.decode(data, response: response, intent: intent) }
        try Task.checkCancellation()
        guard result != .notFound else { throw CloudDeletionError.invalidResponse }
        return result
    }
    func status(_ intent: CloudDeletionIntent) async throws -> CloudDeletionStatus {
        guard intent.isValid else { throw CloudDeletionError.invalidCredentials }
        try Task.checkCancellation()
        // Independent public-key client: never refresh an Auth session that
        // the worker has already removed, or put the receipt in a query URL.
        let result = try await confirmation.invoke("delete-cloud-account/status", options: .init(
            body: StatusBody(operationID: intent.operationID, receiptToken: intent.receiptToken), timeoutInterval: 30
        )) { data, response in try Self.decode(data, response: response, intent: intent) }
        try Task.checkCancellation()
        return result
    }

    private static func decode(_ data: Data, response: HTTPURLResponse, intent: CloudDeletionIntent) throws -> CloudDeletionStatus {
        guard data.count <= 131_072 else { throw CloudDeletionError.invalidResponse }
        let value: WireStatus
        do { value = try JSONDecoder().decode(WireStatus.self, from: data) }
        catch { throw CloudDeletionError.invalidResponse }
        if value.state == "notFound", value.jobID == nil, response.statusCode == 200 { return .notFound }
        guard value.jobID == intent.operationID else { throw CloudDeletionError.invalidResponse }
        if value.state == "pending", response.statusCode == 200 || response.statusCode == 202 { return .pending(intent.operationID) }
        if value.state == "complete", response.statusCode == 200 { return .complete(intent.operationID) }
        throw CloudDeletionError.invalidResponse
    }
    private struct RequestBody: Encodable {
        let workspaceID: UUID; let operationID: UUID; let receiptToken: String
        let nonce: String; let identityToken: String; let authorizationCode: String
    }
    private struct StatusBody: Encodable { let operationID: UUID; let receiptToken: String }
    private struct WireStatus: Decodable { let state: String; let jobID: UUID? }
}
