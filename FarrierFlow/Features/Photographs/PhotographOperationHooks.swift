@MainActor
struct PhotographOperationHooks {
    var afterAddCanonicalMove: () async throws -> Void = {}
    var afterDeleteQuarantineMove: () async throws -> Void = {}
    var beforeDeleteQuarantineRestore: () async throws -> Void = {}
    var afterDiscardQuarantineMoves: () async throws -> Void = {}
    var beforeReconciliationInspection: () async throws -> Void = {}

    static let production = PhotographOperationHooks()
}
