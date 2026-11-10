import Foundation

nonisolated enum EmailAddress {
    static func isValid(_ value: String) -> Bool {
        let address = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard address.utf8.count <= 254, !address.contains(where: { $0.isWhitespace || $0.isNewline }) else { return false }
        let parts = address.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let local = parts[0]
        guard !local.isEmpty, local.utf8.count <= 64,
              !local.hasPrefix("."), !local.hasSuffix("."), !local.contains(".."),
              local.allSatisfy({ $0.isLetter || $0.isNumber || "!#$%&'*+-/=?^_`{|}~.".contains($0) }) else { return false }
        let labels = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2,
              let suffix = labels.last, suffix.count >= 2, suffix.contains(where: \.isLetter) else { return false }
        return labels.allSatisfy { label in
            !label.isEmpty && label.utf8.count <= 63
                && !label.hasPrefix("-") && !label.hasSuffix("-")
                && label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }
    }

    static func isValidOptional(_ value: String) -> Bool {
        TextNormalization.optional(value) == nil || isValid(value)
    }
}
