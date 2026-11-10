import Foundation

enum ClientContactURL {
    static func phone(_ value: String) -> URL? {
        let number = value.filter { !$0.isWhitespace && !"()-.".contains($0) }
        guard number.allSatisfy({ "+0123456789,;".contains($0) }) else { return nil }
        let mainNumber = number.prefix { $0 != "," && $0 != ";" }
        let digits = mainNumber.hasPrefix("+") ? mainNumber.dropFirst() : mainNumber[...]
        guard (3...15).contains(digits.count), digits.allSatisfy(\.isNumber) else { return nil }
        let postDial = number.dropFirst(mainNumber.count)
        guard postDial.isEmpty || (postDial.last?.isNumber == true && !postDial.contains("+")) else { return nil }
        return recipientURL(scheme: "tel", recipient: number)
    }

    static func email(_ value: String) -> URL? {
        let address = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmailAddress.isValid(address) else { return nil }
        return recipientURL(scheme: "mailto", recipient: address)
    }

    private static func recipientURL(scheme: String, recipient: String) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        // Contact text is recipient data, never mail headers or a URL fragment.
        components.path = recipient
        return components.url
    }
}
