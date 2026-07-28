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

    static func makeVisit(
        startedAt: Date = .now,
        completedAt: Date? = nil,
        workItemPolicyVersion: Int = 0,
        appointment: Appointment,
        in context: ModelContext
    ) -> Visit {
        precondition(appointment.visit == nil)
        guard let barn = appointment.barn else {
            preconditionFailure("A Visit fixture requires an Appointment barn.")
        }

        let visit = Visit(
            startedAt: startedAt,
            completedAt: completedAt,
            serviceLocationNameSnapshot: barn.name,
            serviceLocationAddressSnapshot: barn.address,
            workItemPolicyVersion: workItemPolicyVersion,
            appointment: appointment,
            barn: barn
        )
        context.insert(visit)
        appointment.visit = visit
        barn.visits.append(visit)

        for appointmentHorse in appointment.appointmentHorses {
            guard let horse = appointmentHorse.horse else {
                preconditionFailure("A Visit fixture requires every AppointmentHorse to have a Horse.")
            }
            let visitHorse = VisitHorse(visit: visit, horse: horse)
            context.insert(visitHorse)
            visit.visitHorses.append(visitHorse)
            horse.visitHorses.append(visitHorse)
        }
        return visit
    }

    static func makeService(
        name: String = "Front Shoes",
        defaultAmountMinorUnits: Int64 = 12_500,
        currencyCode: String = "USD",
        isArchived: Bool = false,
        in context: ModelContext
    ) -> Service {
        let service = Service(
            name: name,
            defaultAmountMinorUnits: defaultAmountMinorUnits,
            currencyCode: currencyCode,
            isArchived: isArchived
        )
        context.insert(service)
        return service
    }

    static func makeWorkItem(
        service: Service,
        visitHorse: VisitHorse,
        serviceNameSnapshot: String? = nil,
        amountMinorUnits: Int64? = nil,
        currencyCode: String? = nil,
        in context: ModelContext
    ) -> WorkItem {
        let workItem = WorkItem(
            serviceNameSnapshot: serviceNameSnapshot ?? service.name,
            amountMinorUnits: amountMinorUnits ?? service.defaultAmountMinorUnits,
            currencyCode: currencyCode ?? service.currencyCode,
            service: service,
            visitHorse: visitHorse
        )
        context.insert(workItem)
        service.workItems.append(workItem)
        visitHorse.workItems.append(workItem)
        return workItem
    }
}
