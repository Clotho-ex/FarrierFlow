import Foundation

nonisolated enum USDPriceParsingError: Error, Equatable {
    case invalidFormat
    case overflow
}

nonisolated enum USDPriceParser {
    static func parse(_ input: String) throws -> Int64 {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw USDPriceParsingError.invalidFormat
        }

        if value.first == "$" {
            value.removeFirst()
        }
        guard !value.isEmpty else {
            throw USDPriceParsingError.invalidFormat
        }

        let decimalParts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard decimalParts.count <= 2 else {
            throw USDPriceParsingError.invalidFormat
        }

        let wholePart = String(decimalParts[0])
        let fractionalPart = decimalParts.count == 2 ? String(decimalParts[1]) : ""
        guard fractionalPart.count <= 2, fractionalPart.allSatisfy(isASCIIDigit) else {
            throw USDPriceParsingError.invalidFormat
        }

        let wholeDigits = try validatedWholeDigits(wholePart)
        let wholeAmount = try parseDigits(wholeDigits)
        let fractionalAmount = try parseDigits(fractionalPart)
        let scaledFraction = fractionalPart.count == 1 ? fractionalAmount * 10 : fractionalAmount
        let (scaledWhole, wholeOverflow) = wholeAmount.multipliedReportingOverflow(by: 100)
        guard !wholeOverflow else {
            throw USDPriceParsingError.overflow
        }
        let (amount, amountOverflow) = scaledWhole.addingReportingOverflow(scaledFraction)
        guard !amountOverflow else {
            throw USDPriceParsingError.overflow
        }
        return amount
    }

    static func editableString(minorUnits: Int64) -> String? {
        guard minorUnits >= 0 else {
            return nil
        }
        let whole = minorUnits / 100
        let fractional = minorUnits % 100
        return "\(whole).\(String(format: "%02lld", fractional))"
    }

    private static func validatedWholeDigits(_ wholePart: String) throws -> String {
        guard !wholePart.isEmpty else {
            throw USDPriceParsingError.invalidFormat
        }
        guard wholePart.contains(",") else {
            guard wholePart.allSatisfy(isASCIIDigit) else {
                throw USDPriceParsingError.invalidFormat
            }
            return wholePart
        }

        let groups = wholePart.split(separator: ",", omittingEmptySubsequences: false)
        guard
            let firstGroup = groups.first,
            (1 ... 3).contains(firstGroup.count),
            firstGroup.allSatisfy(isASCIIDigit),
            groups.dropFirst().allSatisfy({ group in
                group.count == 3 && group.allSatisfy(isASCIIDigit)
            })
        else {
            throw USDPriceParsingError.invalidFormat
        }
        return groups.joined()
    }

    private static func parseDigits<S: StringProtocol>(_ digits: S) throws -> Int64 {
        var result: Int64 = 0
        for digit in digits {
            guard let value = digit.wholeNumberValue else {
                throw USDPriceParsingError.invalidFormat
            }
            let (multiplied, multiplicationOverflow) = result.multipliedReportingOverflow(by: 10)
            guard !multiplicationOverflow else {
                throw USDPriceParsingError.overflow
            }
            let (next, additionOverflow) = multiplied.addingReportingOverflow(Int64(value))
            guard !additionOverflow else {
                throw USDPriceParsingError.overflow
            }
            result = next
        }
        return result
    }

    private static func isASCIIDigit(_ character: Character) -> Bool {
        character.unicodeScalars.count == 1
            && character.unicodeScalars.allSatisfy { (48 ... 57).contains($0.value) }
    }
}
