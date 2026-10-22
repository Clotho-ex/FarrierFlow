import Foundation

enum ClientContactURL {
    static func phone(_ value: String) -> URL? {
        let number = value.filter { !$0.isWhitespace && !"()-.".contains($0) }
        guard number.contains(where: \.isNumber),
              number.allSatisfy({ "+0123456789,;".contains($0) }) else { return nil }
        return recipientURL(scheme: "tel", recipient: number)
    }

    static func email(_ value: String) -> URL? {
        let address = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard address.contains("@"), !address.contains(where: \.isWhitespace) else { return nil }
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
