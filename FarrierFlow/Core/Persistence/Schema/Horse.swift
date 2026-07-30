import SwiftData

extension FarrierFlowSchemaV1 {
    @Model
    final class Horse {
        var name: String
        var safetyNotes: String?
        var appointmentIntervalWeeks: Int = 6
        var client: Client?
        var currentBarn: Barn?

        @Relationship(deleteRule: .deny, inverse: \AppointmentHorse.horse)
        var appointmentHorses: [AppointmentHorse] = []

        @Relationship(deleteRule: .deny, inverse: \VisitHorse.horse)
        var visitHorses: [VisitHorse] = []

        var defaultService: Service?

        init(
            name: String,
            safetyNotes: String? = nil,
            appointmentIntervalWeeks: Int = 6,
            client: Client,
            currentBarn: Barn,
            defaultService: Service? = nil
        ) {
            self.name = name
            self.safetyNotes = safetyNotes
            self.appointmentIntervalWeeks = appointmentIntervalWeeks
            self.client = client
            self.currentBarn = currentBarn
            self.defaultService = defaultService
        }
    }
}
