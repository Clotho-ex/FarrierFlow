import Testing
@testable import FarrierFlow

@Suite("Checked money totals")
struct CheckedMoneyTotalTests {
    @Test
    func sumsExactNonnegativeMinorUnits() throws {
        #expect(try CheckedMoneyTotal.sum([0, 1_250, 12_500]) == 13_750)
    }

    @Test
    func rejectsNegativeMinorUnits() {
        #expect(throws: CheckedMoneyTotalError.negativeAmount) {
            _ = try CheckedMoneyTotal.sum([1, -1])
        }
    }

    @Test
    func rejectsOverflowWithoutWrapping() {
        #expect(throws: CheckedMoneyTotalError.overflow) {
            _ = try CheckedMoneyTotal.sum([Int64.max, 1])
        }
    }

    @Test
    func computesAvailableOrUnavailableSubtotals() throws {
        #expect(
            try CheckedMoneyTotal.projectedSubtotal(
                [],
                unavailableWhenEmpty: true
            ) == .unavailable
        )
        #expect(
            try CheckedMoneyTotal.projectedSubtotal(
                [],
                unavailableWhenEmpty: false
            ) == .available(0)
        )
        #expect(
            try CheckedMoneyTotal.projectedSubtotal(
                [1_250, 12_500],
                unavailableWhenEmpty: true
            ) == .available(13_750)
        )
    }

    @Test
    func propagatesUnavailableAndCheckedOverflowToVisitTotal() throws {
        #expect(
            try CheckedMoneyTotal.projectedTotal([.available(1_250), .unavailable])
                == .unavailable
        )
        #expect(throws: CheckedMoneyTotalError.overflow) {
            _ = try CheckedMoneyTotal.projectedTotal([.available(Int64.max), .available(1)])
        }
    }
}
