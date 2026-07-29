import Foundation

nonisolated enum HorseHistoryRules {
    static func entries(
        from records: [HorseHistoryRecord],
        locale: Locale
    ) throws -> [HorseHistoryEntry] {
        let entries = try records.compactMap { record -> HorseHistoryEntry? in
            guard let outcome = VisitOutcome(rawValue: record.outcomeRawValue) else {
                throw HorseHistoryLoadError.invalidHistory
            }
            guard let completedAt = record.completedAt else {
                return nil
            }
            guard
                completedAt >= record.startedAt,
                TextNormalization.required(record.horseName) != nil,
                TextNormalization.required(record.serviceLocationName) != nil,
                record.workItemPolicyVersion == 0 || record.workItemPolicyVersion == 1
            else {
                throw HorseHistoryLoadError.invalidHistory
            }

            let hasWorkNotes = TextNormalization.optional(record.workNotes ?? "") != nil
            guard outcome != .pending, !hasWorkNotes || outcome == .serviced else {
                throw HorseHistoryLoadError.invalidHistory
            }

            let workItemCount: Int?
            let subtotal: MoneyAvailability
            if outcome == .serviced {
                if record.workItemPolicyVersion == 0, record.workItemCount == nil {
                    guard record.subtotal == .unavailable else {
                        throw HorseHistoryLoadError.invalidHistory
                    }
                    workItemCount = nil
                    subtotal = .unavailable
                } else {
                    guard
                        let count = record.workItemCount,
                        count > 0,
                        case .available = record.subtotal
                    else {
                        throw HorseHistoryLoadError.invalidHistory
                    }
                    workItemCount = count
                    subtotal = record.subtotal
                }
            } else {
                guard record.workItemCount == nil else {
                    throw HorseHistoryLoadError.invalidHistory
                }
                workItemCount = nil
                subtotal = record.subtotal
            }

            return HorseHistoryEntry(
                id: record.id,
                visitID: record.visitID,
                horseName: record.horseName,
                startedAt: record.startedAt,
                completedAt: completedAt,
                serviceLocationName: record.serviceLocationName,
                outcome: outcome,
                hasWorkNotes: hasWorkNotes,
                workItemCount: workItemCount,
                subtotal: subtotal
            )
        }

        return entries.sorted { lhs, rhs in
            if lhs.startedAt != rhs.startedAt {
                return lhs.startedAt > rhs.startedAt
            }
            if lhs.completedAt != rhs.completedAt {
                return lhs.completedAt > rhs.completedAt
            }
            let serviceLocationOrder = localizedOrder(
                lhs.serviceLocationName,
                rhs.serviceLocationName,
                locale: locale
            )
            if serviceLocationOrder != .orderedSame {
                return serviceLocationOrder == .orderedAscending
            }
            let horseNameOrder = localizedOrder(
                lhs.horseName,
                rhs.horseName,
                locale: locale
            )
            if horseNameOrder != .orderedSame {
                return horseNameOrder == .orderedAscending
            }
            return lhs.id < rhs.id
        }
    }

    private static func localizedOrder(
        _ lhs: String,
        _ rhs: String,
        locale: Locale
    ) -> ComparisonResult {
        lhs.compare(
            rhs,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: nil,
            locale: locale
        )
    }
}
