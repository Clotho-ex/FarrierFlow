import Foundation
import SwiftData

nonisolated enum NextAppointmentAssistantLoadState: Equatable {
    case loading
    case loaded
    case failed(NextAppointmentAssistantLoadError)
}

nonisolated enum NextAppointmentAssistantLoadError: Error, Equatable {
    case sourceAppointmentUnavailable
    case projectionUnavailable
}

nonisolated enum NextAppointmentHorseUnavailabilityReason: Equatable {
    case alreadyScheduled
    case newerServicedVisit
    case moved
    case clientUnavailable
    case invalidAppointmentInterval
    case invalidOutcome
    case invalidCurrentGraph
}

nonisolated struct NextAppointmentHorseOption: Equatable, Identifiable {
    let id: PersistentIdentifier
    let horseID: PersistentIdentifier
    let horseName: String
    let outcome: VisitOutcome
    let intervalWeeks: Int?
    let suggestedStart: Date?
    var isSelected: Bool
    let unavailabilityReason: NextAppointmentHorseUnavailabilityReason?
    let scheduledAppointmentStart: Date?
    let scheduledServiceLocationName: String?
    let currentServiceLocationName: String?
}

nonisolated struct NextAppointmentAssistantProjection: Equatable {
    let sourceVisitID: PersistentIdentifier
    let sourceBarnID: PersistentIdentifier
    let sourceBarnName: String
    let sourceWorkDate: Date
    let projectionNow: Date
    var options: [NextAppointmentHorseOption]
    var proposedStart: Date
    var hasFollowUpSuggestion: Bool
    var isManuallyOverridden: Bool
}
