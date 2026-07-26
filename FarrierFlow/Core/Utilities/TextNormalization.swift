import Foundation

nonisolated enum TextNormalization {
    static func required(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    static func optional(_ value: String) -> String? {
        required(value)
    }
}
