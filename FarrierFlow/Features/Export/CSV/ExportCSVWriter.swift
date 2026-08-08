import Foundation

nonisolated struct ExportCSVWriter {
    func encode(_ table: ExportCSVTable) throws -> Data {
        var output = record(table.definition.columns)

        for row in table.rows {
            guard row.count == table.definition.columns.count else {
                throw ExportFormatError.invalidRowWidth(
                    relativePath: table.definition.relativePath,
                    expected: table.definition.columns.count,
                    actual: row.count
                )
            }
            output += record(row.map(encodedCell))
        }

        return Data(output.utf8)
    }

    private func record(_ fields: [String]) -> String {
        fields.map(escaped).joined(separator: ",") + "\r\n"
    }

    private func encodedCell(_ cell: ExportCSVCell) -> String {
        switch cell {
        case .empty:
            ""
        case let .raw(value):
            value
        case let .userText(value):
            formulaNeutralized(value)
        }
    }

    private func formulaNeutralized(_ value: String) -> String {
        guard isFormulaRisk(value) else { return value }
        return "'" + value
    }

    private func isFormulaRisk(_ value: String) -> Bool {
        guard let first = value.first else { return false }
        if first == "\t" || first == "\r" || first == "\n" { return true }

        guard let firstNonWhitespace = value.first(where: { !$0.isWhitespace }) else {
            return false
        }
        return "=+-@".contains(firstNonWhitespace)
    }

    private func escaped(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\r") || value.contains("\n") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
