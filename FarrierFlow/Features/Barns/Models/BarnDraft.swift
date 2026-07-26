nonisolated struct BarnDraft: Equatable {
    var name = ""
    var address = ""
    var contactNotes = ""

    var isValid: Bool {
        TextNormalization.required(name) != nil
    }
}
