nonisolated struct BarnDraft: Equatable {
    var name = ""
    var address = ""
    var contactNotes = ""

    var isValid: Bool {
        TextNormalization.required(name) != nil
            && InputLimits.fits(name, maximum: InputLimits.name)
            && InputLimits.fits(address, maximum: InputLimits.address)
            && InputLimits.fits(contactNotes, maximum: InputLimits.notes)
    }
}
