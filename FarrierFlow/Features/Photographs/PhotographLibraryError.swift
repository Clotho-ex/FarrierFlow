nonisolated enum PhotographLibraryError: Error, Equatable {
    case visitHorseUnavailable
    case photographUnavailable
    case photographLimitReached
    case insufficientStorage
    case protectedDataUnavailable
    case invalidPhotographGraph
    case ambiguousQuarantine
    case persistenceFailed
    case rollbackCleanupFailed
    case quarantineRestoreFailed
}
