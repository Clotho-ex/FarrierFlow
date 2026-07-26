import SwiftData

nonisolated enum HorseRelocationRules {
    static func canRelocate(
        appointmentMembershipCount: Int,
        currentBarnID: PersistentIdentifier,
        destinationBarnID: PersistentIdentifier
    ) -> Bool {
        currentBarnID == destinationBarnID || appointmentMembershipCount == 0
    }
}
