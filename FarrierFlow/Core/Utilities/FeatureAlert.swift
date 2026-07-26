import Foundation

nonisolated struct FeatureAlert: Identifiable, Equatable {
    let id: UUID
    let title: LocalizedStringResource
    let message: LocalizedStringResource

    init(
        id: UUID = UUID(),
        title: LocalizedStringResource,
        message: LocalizedStringResource
    ) {
        self.id = id
        self.title = title
        self.message = message
    }
}
