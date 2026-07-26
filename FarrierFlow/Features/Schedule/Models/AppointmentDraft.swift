import Foundation
import SwiftData

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

    var isValid: Bool {
        let duration = expectedDurationText.trimmingCharacters(in: .whitespacesAndNewlines)
        return barnID != nil
            && !selectedHorseIDs.isEmpty
            && (duration.isEmpty || expectedDurationMinutes != nil)
    }
}
