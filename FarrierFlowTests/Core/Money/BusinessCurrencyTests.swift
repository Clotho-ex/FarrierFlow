import Foundation
import Testing
@testable import FarrierFlow

@Suite("Business currencies")
struct BusinessCurrencyTests {
    @Test
    func exposesOnlyTheApprovedBusinessCurrencies() {
        #expect(BusinessCurrency.allCases.map(\.rawValue) == [
            "USD", "TRY", "GBP", "EUR", "CAD", "AUD", "NZD", "ZAR",
        ])
        #expect(BusinessCurrency.isSupported("GBP"))
        #expect(!BusinessCurrency.isSupported("gbp"))
        #expect(!BusinessCurrency.isSupported("JPY"))
    }

    @Test(arguments: [
        ("en_US", "USD"),
        ("tr_TR", "TRY"),
        ("en_GB", "GBP"),
        ("en_IE", "EUR"),
        ("en_CA", "CAD"),
        ("en_AU", "AUD"),
        ("en_NZ", "NZD"),
        ("en_ZA", "ZAR"),
        ("ja_JP", "USD"),
    ])
    func defaultsFromSupportedLocaleCurrency(
        localeIdentifier: String,
        expectedCode: String
    ) {
        #expect(
            BusinessCurrency.defaultCode(
                for: Locale(identifier: localeIdentifier)
            ) == expectedCode
        )
    }
}
