nonisolated enum BusinessProfileRulesError: Error, Equatable {
    case nameRequired
    case defaultAppointmentDurationInvalid
    case defaultInvoiceDueDaysInvalid
}

nonisolated enum BusinessProfileRules {
    static func validated(
        _ draft: BusinessProfileDraft
    ) throws -> BusinessProfileValues {
        guard let name = TextNormalization.required(draft.name) else {
            throw BusinessProfileRulesError.nameRequired
        }
        if let duration = draft.defaultAppointmentDurationMinutes, duration <= 0 {
            throw BusinessProfileRulesError.defaultAppointmentDurationInvalid
        }
        if let dueDays = draft.defaultInvoiceDueDays, dueDays <= 0 {
            throw BusinessProfileRulesError.defaultInvoiceDueDaysInvalid
        }

        return BusinessProfileValues(
            name: name,
            phone: TextNormalization.optional(draft.phone),
            email: TextNormalization.optional(draft.email),
            address: TextNormalization.optional(draft.address),
            defaultInvoiceNote: TextNormalization.optional(draft.defaultInvoiceNote),
            defaultAppointmentDurationMinutes: draft.defaultAppointmentDurationMinutes,
            defaultInvoiceDueDays: draft.defaultInvoiceDueDays
        )
    }
}
