import Foundation
import SwiftData

nonisolated struct CompletedVisitRecency: Equatable {
    let visitID: PersistentIdentifier
    let startedAt: Date
    let completedAt: Date

    init?(visitID: PersistentIdentifier, startedAt: Date, completedAt: Date) {
        guard completedAt >= startedAt else {
            return nil
        }

        self.visitID = visitID
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    static func precedes(
        _ candidate: CompletedVisitRecency,
        _ source: CompletedVisitRecency,
        sourceVisitID: PersistentIdentifier
    ) -> Bool {
        guard candidate.visitID != sourceVisitID else {
            return false
        }

        if candidate.startedAt != source.startedAt {
            return candidate.startedAt > source.startedAt
        }

        if candidate.completedAt != source.completedAt {
            return candidate.completedAt > source.completedAt
        }

        return candidate.visitID < source.visitID
    }
}

nonisolated enum NextAppointmentSuggestionRules {
    static func suggestedStart(
        visitStartedAt: Date,
        intervalWeeks: Int,
        sourceAppointmentStart: Date,
        calendar: Calendar
    ) -> Date? {
        guard intervalWeeks > 0 else {
            return nil
        }

        let workDay = calendar.startOfDay(for: visitStartedAt)
        guard let suggestedDay = calendar.date(
            byAdding: .weekOfYear,
            value: intervalWeeks,
            to: workDay
        ) else {
            return nil
        }

        let sourceTime = calendar.dateComponents(
            [.hour, .minute],
            from: sourceAppointmentStart
        )
        guard let hour = sourceTime.hour, let minute = sourceTime.minute else {
            return nil
        }

        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: suggestedDay,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    static func groupSuggestedStart(selectedSuggestedDates: [Date]) -> Date? {
        selectedSuggestedDates.min()
    }

    static func editorStart(
        groupSuggestion: Date?,
        now: Date,
        calendar: Calendar
    ) -> Date {
        guard let groupSuggestion, groupSuggestion >= now else {
            return AppointmentStartDateRules.nextHalfHour(after: now, calendar: calendar)
        }

        return groupSuggestion
    }
}
