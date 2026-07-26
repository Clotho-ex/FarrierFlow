import SwiftData

nonisolated struct HorseDraft: Equatable {
    var name = ""
    var safetyNotes = ""
    var appointmentIntervalWeeks = 6
    var clientID: PersistentIdentifier?
    var barnID: PersistentIdentifier?

    var isValid: Bool {
        TextNormalization.required(name) != nil
            && appointmentIntervalWeeks > 0
            && clientID != nil
            && barnID != nil
    }
}
