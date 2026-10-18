import Foundation
import Observation
import SwiftData

nonisolated enum CloudDeletionRunState: Equatable, Sendable {
    case localOnly, awaitingApple, submitting, unconfirmed, pending, complete
}

@MainActor
@Observable
final class CloudDeletionController {
    private let store: SyncJournalStore
    private let receipts: CloudDeletionReceiptStore
    private let transport: any CloudDeletionTransport
    private let stopped: @MainActor () -> Void
    @ObservationIgnored private var challenge: AppleSignInChallenge?
    @ObservationIgnored private var epoch = UUID()
    private var retainedFence = false
    private(set) var intent: CloudDeletionIntent?
    private(set) var receiptUnavailable = false
    private(set) var isChecking = false
    private(set) var state: CloudDeletionRunState = .localOnly
    var isFenced: Bool { receiptUnavailable || intent != nil || retainedFence }
    var isBusy: Bool { state == .submitting || isChecking }

    init(container: ModelContainer, receipts: CloudDeletionReceiptStore,
         transport: any CloudDeletionTransport, stopped: @escaping @MainActor () -> Void) {
        store = SyncJournalStore(container: container)
        self.receipts = receipts
        self.transport = transport
        self.stopped = stopped
    }
    func prepare(accountID: UUID) throws -> AppleSignInChallenge {
        guard !isBusy, state != .pending, state != .complete else { throw CloudDeletionError.invalidPhase }
        guard let journal = try store.journal() else { throw SyncJournalStoreError.unbound }
        try journal.verifyBinding(accountID: accountID, workspaceID: journal.workspaceID)
        let prepared = try receipts.prepare(accountID: accountID, workspaceID: journal.workspaceID)
        guard prepared.phase == .prepared || prepared.phase == .sent else { throw CloudDeletionError.invalidPhase }
        let challenge = try AppleSignInChallenge()
        epoch = UUID()
        intent = prepared
        self.challenge = challenge
        state = .awaitingApple
        stopped()
        return challenge
    }
    func cancelPrepared() throws {
        guard let intent else { return }
        try receipts.cancelPrepared(intent)
        epoch = UUID()
        challenge = nil
        self.intent = nil
        receiptUnavailable = false
        state = .localOnly
    }
    func cancelAuthorization() throws {
        guard let intent else { return }
        if intent.phase == .prepared { try cancelPrepared() }
        else {
            epoch = UUID()
            challenge = nil
            state = .unconfirmed
        }
    }
    func submit(identityToken: Data, authorizationCode: Data) async {
        guard state == .awaitingApple, let intent, let challenge else { return }
        let generation = epoch
        self.challenge = nil
        state = .submitting
        do {
            try receipts.advance(intent, to: .sent)
            self.intent = try receipts.load()
            let status = try await transport.request(intent, identityToken: identityToken,
                authorizationCode: authorizationCode, challenge: challenge)
            try check(generation)
            try accept(status, for: intent)
        } catch {
            guard epoch == generation else { return }
            state = .unconfirmed
        }
    }
    func refresh() async {
        guard !isBusy, let intent else { return }
        isChecking = true
        defer { isChecking = false }
        let generation = epoch
        stopped()
        do {
            let status = try await transport.status(intent)
            try check(generation)
            if status == .notFound {
                // An earlier timed-out request could still be exchanging its
                // Apple code. Not found is not proof that it can be cancelled.
                state = intent.phase == .prepared ? .awaitingApple : .unconfirmed
            } else { try accept(status, for: intent) }
        } catch {
            guard epoch == generation else { return }
            state = .unconfirmed
        }
    }
    func resume() async {
        guard !isBusy else { return }
        do {
            let retained = try store.retainedDeletion()
            retainedFence = retained != nil
            intent = try receipts.load()
            receiptUnavailable = false
            guard let intent else {
                if let retained {
                    stopped()
                    state = retained.completed ? .complete : .unconfirmed
                } else { state = .localOnly }
                return
            }
            stopped()
            if intent.phase == .complete {
                if try store.isBound(to: intent) { try accept(.complete(intent.operationID), for: intent) }
                else {
                    // Completed device receipts can outlive an app reinstall.
                    // Retire only confirmed completion, never an ambiguous send.
                    try receipts.retireCompleted(intent)
                    self.intent = nil
                    state = retained?.completed == true ? .complete : (retained == nil ? .localOnly : .unconfirmed)
                }
            }
            else if intent.phase == .prepared { state = .awaitingApple }
            else { state = intent.phase == .queued ? .pending : .unconfirmed; await refresh() }
        } catch {
            // A locked/corrupt receipt must not cause automatic re-upload.
            receiptUnavailable = true
            stopped()
            state = .unconfirmed
        }
    }
    private func accept(_ status: CloudDeletionStatus, for intent: CloudDeletionIntent) throws {
        switch status {
        case .pending(let id), .complete(let id):
            guard id == intent.operationID else { throw CloudDeletionError.invalidResponse }
        case .notFound: throw CloudDeletionError.invalidResponse
        }
        if try store.isBound(to: intent) { try store.recordCloudDeletion(intent, status: status) }
        let phase: CloudDeletionPhase
        switch status {
        case .pending: phase = .queued
        case .complete: phase = .complete
        case .notFound: throw CloudDeletionError.invalidResponse
        }
        try receipts.advance(intent, to: phase)
        self.intent = try receipts.load()
        guard self.intent != nil else { throw CloudDeletionError.receiptNotStored }
        let retained = try store.retainedDeletion()
        retainedFence = retained != nil
        if phase == .complete {
            try receipts.retireCompleted(intent)
            self.intent = nil
        }
        state = phase == .complete ?
            (retained?.completed == true ? .complete : (retained == nil ? .localOnly : .unconfirmed)) : .pending
        stopped()
    }
    private func check(_ generation: UUID) throws {
        try Task.checkCancellation()
        guard epoch == generation else { throw CancellationError() }
    }
}
