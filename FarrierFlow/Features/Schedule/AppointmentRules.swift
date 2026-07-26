import SwiftData

nonisolated enum AppointmentValidationResult: Equatable {
    case valid
    case noHorses
    case duplicateHorse
    case ineligibleHorse
}

nonisolated enum AppointmentRules {
    static func validate(
        selectedHorseIDs: [PersistentIdentifier],
        eligibleHorseIDs: Set<PersistentIdentifier>
    ) -> AppointmentValidationResult {
        guard !selectedHorseIDs.isEmpty else { return .noHorses }
        guard Set(selectedHorseIDs).count == selectedHorseIDs.count else {
            return .duplicateHorse
        }
        guard selectedHorseIDs.allSatisfy(eligibleHorseIDs.contains) else {
            return .ineligibleHorse
        }
        return .valid
    }
}
