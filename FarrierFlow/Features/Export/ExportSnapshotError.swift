nonisolated enum ExportSnapshotError: Error, Equatable {
    case invalidBatchSize(Int)
    case batchSizeExceedsMaximum(Int)
    case invalidGraph(DomainGraphViolation)
    case sourceGraphChanged(ExportEntity)
    case missingProjectedRelationship(entity: ExportEntity, relationship: String)
    case unsupportedVisitOutcome(String)
    case unsupportedInvoiceStatus(String)
    case invalidInvoicePaymentState
    case invalidInvoiceNumber(Int64)
    case invalidInvoiceTotal
}
