import Foundation

nonisolated enum PhotographFileStoreError: Error, Equatable {
    case destinationExists
    case unmanagedURL
    case expectedRegularFile
    case directoryUnavailable
}
