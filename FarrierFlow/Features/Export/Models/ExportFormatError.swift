import Foundation

nonisolated enum ExportFormatError: Error, Equatable {
    case unsupportedVisitOutcome(String)
    case unsupportedInvoiceStatus(String)
    case unsupportedCurrencyCode(String)
    case invalidMonetaryValue(Int64)
    case missingPhotographResult(UUID)
    case invalidPhotographCopy(relativePath: String, byteCount: Int64)
    case invalidRowWidth(relativePath: String, expected: Int, actual: Int)
}
