nonisolated enum BusinessProfileRulesError: Error, Equatable {
    case nameRequired
}

nonisolated enum BusinessProfileRules {
    static func validated(
        _ draft: BusinessProfileDraft
    ) throws -> BusinessProfileValues {
        guard let name = TextNormalization.required(draft.name) else {
            throw BusinessProfileRulesError.nameRequired
        }

        return BusinessProfileValues(
            name: name,
            phone: TextNormalization.optional(draft.phone),
            email: TextNormalization.optional(draft.email),
            address: TextNormalization.optional(draft.address),
            defaultInvoiceNote: TextNormalization.optional(draft.defaultInvoiceNote)
        )
    }
}
