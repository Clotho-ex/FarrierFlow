import SwiftData

extension FarrierFlowSchemaV2 {
    @Model
    final class Barn {
        var name: String
        var address: String?
        var contactNotes: String?

        @Relationship(deleteRule: .deny, inverse: \Horse.currentBarn)
        var horses: [Horse] = []

        @Relationship(deleteRule: .deny, inverse: \Appointment.barn)
        var appointments: [Appointment] = []

        @Relationship(deleteRule: .deny, inverse: \Visit.barn)
        var visits: [Visit] = []

        init(
            name: String,
            address: String? = nil,
            contactNotes: String? = nil
        ) {
            self.name = name
            self.address = address
            self.contactNotes = contactNotes
        }
    }
}
