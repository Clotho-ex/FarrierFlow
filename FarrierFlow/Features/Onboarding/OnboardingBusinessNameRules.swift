import Foundation

nonisolated enum OnboardingBusinessNameValidationError: Error, Equatable {
    case required
    case unsupportedCharacters
    case vulgarity
}

nonisolated enum OnboardingBusinessNameRules {
    private static let blockedWords: Set<String> = [
        "asshole",
        "bastard",
        "bitch",
        "bullshit",
        "cunt",
        "dick",
        "fuck",
        "fucker",
        "fucking",
        "motherfucker",
        "piss",
        "prick",
        "shit",
        "slut",
        "whore",
    ]

    static func validated(_ rawValue: String) throws -> String {
        guard let name = TextNormalization.required(rawValue) else {
            throw OnboardingBusinessNameValidationError.required
        }
        guard name.allSatisfy({ character in
            character.isLetter || character.isNumber || character == " "
        }) else {
            throw OnboardingBusinessNameValidationError.unsupportedCharacters
        }

        let words = name
            .lowercased()
            .split(separator: " ")
            .map(String.init)
        guard blockedWords.isDisjoint(with: words) else {
            throw OnboardingBusinessNameValidationError.vulgarity
        }
        return name
    }
}
