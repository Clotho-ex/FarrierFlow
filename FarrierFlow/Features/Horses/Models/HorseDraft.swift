import SwiftData

nonisolated enum HorseRequiredField: Hashable { case name, client, serviceLocation }

nonisolated struct HorseDraft: Equatable {
    var name = ""
    var safetyNotes = ""
    var appointmentIntervalWeeks = 6
    var clientID: PersistentIdentifier?
    var barnID: PersistentIdentifier?
    var defaultServiceID: PersistentIdentifier?

    var missingRequiredFields: Set<HorseRequiredField> {
        var fields = Set<HorseRequiredField>()
        if TextNormalization.required(name) == nil { fields.insert(.name) }
        if clientID == nil { fields.insert(.client) }
        if barnID == nil { fields.insert(.serviceLocation) }
        return fields
    }

    var isValid: Bool {
        TextNormalization.required(name) != nil
            && appointmentIntervalWeeks > 0
            && clientID != nil
            && barnID != nil
    }
}
