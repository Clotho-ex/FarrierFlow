import Foundation

nonisolated enum RecordSearch {
    static func matches(_ query: String, fields: [String]) -> Bool {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return terms.allSatisfy { term in
            fields.contains { $0.localizedStandardContains(term) }
        }
    }
}
