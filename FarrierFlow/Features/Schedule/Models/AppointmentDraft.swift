import Foundation
import SwiftData

nonisolated enum AppointmentSaveRequirement: Equatable {
    case serviceLocation
    case horse
    case expectedDuration
    case lockedMembership
}

nonisolated struct AppointmentDraft: Equatable {
    var barnID: PersistentIdentifier?
    var startDate: Date
    var selectedHorseIDs: Set<PersistentIdentifier>
    var notes = ""
    var expectedDurationText = ""

    init(
        barnID: PersistentIdentifier? = nil,
        startDate: Date = .now,
        selectedHorseIDs: Set<PersistentIdentifier> = [],
        notes: String = "",
        expectedDurationText: String = ""
    ) {
        self.barnID = barnID
        self.startDate = startDate
        self.selectedHorseIDs = selectedHorseIDs
        self.notes = notes
        self.expectedDurationText = expectedDurationText
    }

    var expectedDurationMinutes: Int? {
        let normalized = expectedDurationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        guard let value = Int(normalized), value > 0 else { return nil }
        return value
    }

    var saveRequirement: AppointmentSaveRequirement? {
        guard barnID != nil else { return .serviceLocation }
        guard !selectedHorseIDs.isEmpty else { return .horse }
        let duration = expectedDurationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard duration.isEmpty || expectedDurationMinutes != nil else {
            return .expectedDuration
        }
        return nil
    }

    var isValid: Bool {
        saveRequirement == nil
    }
}
