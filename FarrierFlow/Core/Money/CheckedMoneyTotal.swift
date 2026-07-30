nonisolated enum CheckedMoneyTotalError: Error, Equatable {
    case negativeAmount
    case overflow
}

nonisolated enum CheckedMoneyTotal {
    static func sum<S: Sequence>(_ amounts: S) throws -> Int64 where S.Element == Int64 {
        var total: Int64 = 0
        for amount in amounts {
            guard amount >= 0 else {
                throw CheckedMoneyTotalError.negativeAmount
            }
            let (nextTotal, overflow) = total.addingReportingOverflow(amount)
            guard !overflow else {
                throw CheckedMoneyTotalError.overflow
            }
            total = nextTotal
        }
        return total
    }

    static func projectedSubtotal<S: Sequence>(
        _ amounts: S,
        unavailableWhenEmpty: Bool
    ) throws -> MoneyAvailability where S.Element == Int64 {
        let amounts = Array(amounts)
        guard !amounts.isEmpty || !unavailableWhenEmpty else {
            return .unavailable
        }
        return .available(try sum(amounts))
    }

    static func projectedTotal<S: Sequence>(_ subtotals: S) throws -> MoneyAvailability
    where S.Element == MoneyAvailability {
        var amounts = [Int64]()
        for subtotal in subtotals {
            switch subtotal {
            case let .available(amount):
                amounts.append(amount)
            case .unavailable:
                return .unavailable
            }
        }
        return .available(try sum(amounts))
    }
}
