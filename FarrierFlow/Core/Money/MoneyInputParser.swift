import Foundation

nonisolated enum MoneyInputParsingError: Error, Equatable {
    case invalidFormat
    case overflow
    case unsupportedCurrency
}

nonisolated enum MoneyInputParser {
    static func parse(
        _ input: String,
        currencyCode: String,
        locale: Locale = .current
    ) throws -> Int64 {
        guard BusinessCurrency.isSupported(currencyCode) else {
            throw MoneyInputParsingError.unsupportedCurrency
        }

        let decimalSeparator = locale.decimalSeparator ?? "."
        let groupingSeparator = locale.groupingSeparator ?? ","
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        value = removingLeadingCurrencySymbol(
            from: value,
            currencyCode: currencyCode,
            locale: locale
        )
        guard !value.isEmpty else {
            throw MoneyInputParsingError.invalidFormat
        }

        let decimalParts = value.components(separatedBy: decimalSeparator)
        guard decimalParts.count <= 2 else {
            throw MoneyInputParsingError.invalidFormat
        }

        let wholePart = decimalParts[0]
        let fractionalPart = decimalParts.count == 2 ? decimalParts[1] : ""
        guard
            fractionalPart.count <= 2,
            fractionalPart.allSatisfy(isASCIIDigit)
        else {
            throw MoneyInputParsingError.invalidFormat
        }

        let wholeDigits = try validatedWholeDigits(
            wholePart,
            groupingSeparator: groupingSeparator
        )
        let wholeAmount = try parseDigits(wholeDigits)
        let fractionalAmount = try parseDigits(fractionalPart)
        let scaledFraction = fractionalPart.count == 1
            ? fractionalAmount * 10
            : fractionalAmount
        let (scaledWhole, wholeOverflow) = wholeAmount.multipliedReportingOverflow(by: 100)
        guard !wholeOverflow else {
            throw MoneyInputParsingError.overflow
        }
        let (amount, amountOverflow) = scaledWhole.addingReportingOverflow(scaledFraction)
        guard !amountOverflow else {
            throw MoneyInputParsingError.overflow
        }
        return amount
    }

    static func editableString(
        minorUnits: Int64,
        locale: Locale = .current
    ) -> String? {
        guard minorUnits >= 0 else {
            return nil
        }
        let decimalSeparator = locale.decimalSeparator ?? "."
        let whole = minorUnits / 100
        let fractional = minorUnits % 100
        return "\(whole)\(decimalSeparator)\(String(format: "%02lld", fractional))"
    }

    private static func removingLeadingCurrencySymbol(
        from input: String,
        currencyCode: String,
        locale: Locale
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currencyCode

        guard
            let symbol = formatter.currencySymbol,
            !symbol.isEmpty,
            input.hasPrefix(symbol)
        else {
            return input
        }
        return String(input.dropFirst(symbol.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func validatedWholeDigits(
        _ wholePart: String,
        groupingSeparator: String
    ) throws -> String {
        guard !wholePart.isEmpty else {
            throw MoneyInputParsingError.invalidFormat
        }
        guard
            !groupingSeparator.isEmpty,
            wholePart.contains(groupingSeparator)
        else {
            guard wholePart.allSatisfy(isASCIIDigit) else {
                throw MoneyInputParsingError.invalidFormat
            }
            return wholePart
        }

        let groups = wholePart.components(separatedBy: groupingSeparator)
        guard
            let firstGroup = groups.first,
            (1 ... 3).contains(firstGroup.count),
            firstGroup.allSatisfy(isASCIIDigit),
            groups.dropFirst().allSatisfy({ group in
                group.count == 3 && group.allSatisfy(isASCIIDigit)
            })
        else {
            throw MoneyInputParsingError.invalidFormat
        }
        return groups.joined()
    }

    private static func parseDigits<S: StringProtocol>(_ digits: S) throws -> Int64 {
        var result: Int64 = 0
        for digit in digits {
            guard let value = digit.wholeNumberValue else {
                throw MoneyInputParsingError.invalidFormat
            }
            let (multiplied, multiplicationOverflow) = result.multipliedReportingOverflow(by: 10)
            guard !multiplicationOverflow else {
                throw MoneyInputParsingError.overflow
            }
            let (next, additionOverflow) = multiplied.addingReportingOverflow(Int64(value))
            guard !additionOverflow else {
                throw MoneyInputParsingError.overflow
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
