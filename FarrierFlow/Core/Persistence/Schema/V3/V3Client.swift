import SwiftData

extension FarrierFlowSchemaV3 {
    @Model
    final class Client {
        var name: String
        var phone: String?
        var email: String?
        var notes: String?

        @Relationship(deleteRule: .deny, inverse: \Horse.client)
        var horses: [Horse] = []

        init(
            name: String,
            phone: String? = nil,
            email: String? = nil,
            notes: String? = nil
        ) {
            self.name = name
            self.phone = phone
            self.email = email
            self.notes = notes
        }
    }
}
