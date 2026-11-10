import Foundation
import PhoneNumberKit

@MainActor
enum PhoneNumberFormatting {
    private static let utility = PhoneNumberUtility()

    static func display(_ raw: String) -> String {
        // A saved local number has no reliable country context. Never reinterpret it on another phone.
        guard raw.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("+") else { return raw }
        // The explicit country code controls parsing; the library still requires a supported fallback region.
        return formattedInput(raw, region: "US")
    }

    static func formattedInput(_ raw: String, region: String) -> String {
        guard let (number, postDial) = parsed(raw, region: region) else { return raw }
        let formatted = utility.format(number, toType: .international) + postDial
        return formatted.count <= InputLimits.phone ? formatted : raw
    }

    static func nationalDigits(_ raw: String) -> String? {
        guard raw.hasPrefix("+"), let (number, _) = parsed(raw, region: "US") else { return nil }
        return utility.format(number, toType: .national).filter(\.isNumber)
    }

    static func normalized(_ raw: String, region: String) -> String? {
        guard let (number, postDial) = parsed(raw, region: region) else { return nil }
        return utility.format(number, toType: .e164) + postDial
    }

    private static func parsed(_ raw: String, region: String) -> (PhoneNumber, String)? {
        guard ClientContactURL.phone(raw) != nil else { return nil }
        let main = raw.prefix { $0 != "," && $0 != ";" }
        let postDial = String(raw.dropFirst(main.count)).filter { !$0.isWhitespace }
        guard let number = try? utility.parse(String(main), withRegion: region, ignoreType: true) else { return nil }
        return (number, postDial)
    }
}
