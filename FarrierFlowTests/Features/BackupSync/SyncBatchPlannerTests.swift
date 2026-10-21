import Foundation
import Testing
@testable import FarrierFlow

@Suite("Sync dependency planning")
struct SyncBatchPlannerTests {
    @Test
    func deletingALocationKeepsItsLargeHistoryInOneTransaction() throws {
        let barn = UUID(), horse = UUID(), client = UUID(), service = UUID()
        var baseline: [SyncRecord] = [
            .init(id: barn, kind: .barn, fields: [:]),
            .init(id: horse, kind: .horse, fields: ["client": reference(client), "currentBarn": reference(barn)]),
            .init(id: client, kind: .client, fields: [:]),
            .init(id: service, kind: .service, fields: [:])
        ]
        for _ in 0..<1_000 {
            let appointment = UUID(), member = UUID(), visit = UUID(), visitHorse = UUID(), work = UUID()
            baseline.append(contentsOf: [
                .init(id: appointment, kind: .appointment, fields: ["barn": reference(barn)]),
                .init(id: member, kind: .appointmentHorse, fields: ["appointment": reference(appointment), "horse": reference(horse)]),
                .init(id: visit, kind: .visit, fields: ["appointment": reference(appointment), "barn": reference(barn)]),
                .init(id: visitHorse, kind: .visitHorse, fields: ["visit": reference(visit), "horse": reference(horse)]),
                .init(id: work, kind: .workItem, fields: ["visitHorse": reference(visitHorse), "service": reference(service)])
            ])
        }
        let mutations = baseline.filter { $0.id != client && $0.id != service }.map {
            SyncMutation(id: $0.id, kind: $0.kind, expectedRevision: 1, record: nil)
        }
        let selected = try SyncBatchPlanner.select(from: mutations, baseline: baseline, headerBytes: 200)
        #expect(selected.count == 5_002)
        #expect(Set(selected.map(\.id)) == Set(mutations.map(\.id)))
        #expect(selected.allSatisfy { $0.record == nil })
    }

    @Test(arguments: [false, true])
    func unchangedMembershipConnectsHorseAndAppointmentMoves(deletingOldBarn: Bool) throws {
        let oldBarn = UUID(), newBarn = UUID(), horse = UUID(), appointment = UUID(), member = UUID()
        let baseline: [SyncRecord] = [
            .init(id: oldBarn, kind: .barn, fields: [:]),
            .init(id: newBarn, kind: .barn, fields: [:]),
            .init(id: horse, kind: .horse, fields: ["currentBarn": reference(oldBarn)]),
            .init(id: appointment, kind: .appointment, fields: ["barn": reference(oldBarn)]),
            .init(id: member, kind: .appointmentHorse, fields: ["appointment": reference(appointment), "horse": reference(horse)])
        ]
        var mutations: [SyncMutation] = [
            .init(id: horse, kind: .horse, expectedRevision: 1,
                  record: .init(id: horse, kind: .horse, fields: ["currentBarn": reference(newBarn)])),
            .init(id: appointment, kind: .appointment, expectedRevision: 1,
                  record: .init(id: appointment, kind: .appointment, fields: ["barn": reference(newBarn)]))
        ]
        var required: Set<UUID> = [horse, appointment]
        if deletingOldBarn {
            required.insert(oldBarn)
            mutations.append(.init(id: oldBarn, kind: .barn, expectedRevision: 1, record: nil))
        }
        let selected = try SyncBatchPlanner.select(from: mutations, baseline: baseline, headerBytes: 200, softLimit: 1)
        #expect(Set(selected.map(\.id)) == required)
    }

    private func reference(_ id: UUID) -> SyncValue { .string(id.uuidString.lowercased()) }
}
