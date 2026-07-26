import Foundation
import SwiftData

enum PreviewFixtures {
    static func seed(_ context: ModelContext) throws {
        let client = Client(name: "Preview Client")
        let barn = Barn(
            name: "Preview Service Location",
            address: "100 Sample Road"
        )
        context.insert(client)
        context.insert(barn)

        let horse = Horse(
            name: "Preview Horse",
            client: client,
            currentBarn: barn
        )
        context.insert(horse)
        client.horses.append(horse)
        barn.horses.append(horse)

        let appointment = Appointment(
            startDate: .now,
            barn: barn
        )
        context.insert(appointment)
        barn.appointments.append(appointment)

        let appointmentHorse = AppointmentHorse(
            appointment: appointment,
            horse: horse
        )
        context.insert(appointmentHorse)
        appointment.appointmentHorses.append(appointmentHorse)
        horse.appointmentHorses.append(appointmentHorse)
        try DomainGraphValidator.save(context)
    }
}
