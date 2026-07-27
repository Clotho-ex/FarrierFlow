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
                TextNormalization.required(record.serviceLocationName) != nil
            else {
                throw HorseHistoryLoadError.invalidHistory
            }

            let hasWorkNotes = TextNormalization.optional(record.workNotes ?? "") != nil
            guard outcome != .pending, !hasWorkNotes || outcome == .serviced else {
                throw HorseHistoryLoadError.invalidHistory
            }

            return HorseHistoryEntry(
                id: record.id,
                visitID: record.visitID,
                horseName: record.horseName,
                startedAt: record.startedAt,
                completedAt: completedAt,
                serviceLocationName: record.serviceLocationName,
                outcome: outcome,
                hasWorkNotes: hasWorkNotes
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
            return localizedOrder(lhs.horseName, rhs.horseName, locale: locale) == .orderedAscending
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
