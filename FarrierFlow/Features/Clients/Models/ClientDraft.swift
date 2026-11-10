nonisolated struct ClientDraft: Equatable {
    var name = ""
    var phone = ""
    var email = ""
    var notes = ""

    var isValid: Bool {
        TextNormalization.required(name) != nil
            && InputLimits.fits(name, maximum: InputLimits.name)
            && InputLimits.fits(phone, maximum: InputLimits.phone)
            && InputLimits.fits(email, maximum: InputLimits.email)
            && InputLimits.fits(notes, maximum: InputLimits.notes)
            && EmailAddress.isValidOptional(email)
    }
}
