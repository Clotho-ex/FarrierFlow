nonisolated enum ExportCSVCell: Sendable, Equatable {
    case empty
    case raw(String)
    case userText(String)
}

nonisolated struct ExportCSVTable: Sendable, Equatable {
    let definition: ExportCSVDefinition
    let rows: [[ExportCSVCell]]
}
