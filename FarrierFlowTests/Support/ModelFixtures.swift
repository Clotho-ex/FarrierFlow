import Foundation
import SwiftData
@testable import FarrierFlow

enum ModelFixtures {
    static func makeClient(name: String = "Alex Carter") -> Client {
        Client(name: name)
    }

    static func makeBarn(name: String = "North Field") -> Barn {
        Barn(name: name)
    }

    static func makeHorse(
        name: String = "Milo",
        client: Client,
        barn: Barn
    ) -> Horse {
        Horse(name: name, client: client, currentBarn: barn)
    }

    static func makeAppointment(
        startDate: Date = .now,
        barn: Barn,
        horses: [Horse],
        in context: ModelContext
    ) -> Appointment {
        let appointment = Appointment(startDate: startDate, barn: barn)
        context.insert(appointment)
        barn.appointments.append(appointment)
        for horse in horses {
            let appointmentHorse = AppointmentHorse(
                appointment: appointment,
                horse: horse
            )
            context.insert(appointmentHorse)
            appointment.appointmentHorses.append(appointmentHorse)
            horse.appointmentHorses.append(appointmentHorse)
        }
        return appointment
    }
}
