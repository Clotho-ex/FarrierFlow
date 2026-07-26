nonisolated struct ClientDraft: Equatable {
    var name = ""
    var phone = ""
    var email = ""
    var notes = ""

    var isValid: Bool {
        TextNormalization.required(name) != nil
    }
}
