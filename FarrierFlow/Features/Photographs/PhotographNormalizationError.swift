nonisolated enum PhotographNormalizationError: Error, Equatable {
    case invalidSource
    case destinationExists
    case renderFailed
    case encodingFailed
    case validationFailed
    case metadataPresent
    case colorSpaceMismatch
}
