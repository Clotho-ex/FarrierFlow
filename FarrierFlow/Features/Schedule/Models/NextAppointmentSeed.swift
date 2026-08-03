import Foundation
import SwiftData

nonisolated struct NextAppointmentSeed: Equatable {
    let barnID: PersistentIdentifier
    let horseIDs: Set<PersistentIdentifier>
    let startDate: Date
    let hasFollowUpSuggestion: Bool
}
