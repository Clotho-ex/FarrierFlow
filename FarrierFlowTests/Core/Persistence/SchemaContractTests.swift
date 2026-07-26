import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("SwiftData V1 schema contract")
struct SchemaContractTests {
    private let schema = Schema(versionedSchema: FarrierFlowSchemaV1.self)

    @Test
    func schemaRegistersExactlyFiveModels() {
        let entityNames = Set(schema.entities.map(\.name))

        #expect(entityNames == [
            "Client",
            "Barn",
            "Horse",
            "Appointment",
            "AppointmentHorse",
        ])
    }

    @Test
    func clientAndBarnHaveNoDirectRelationship() throws {
        let client = try #require(schema.entitiesByName["Client"])
        let barn = try #require(schema.entitiesByName["Barn"])

        #expect(client.relationships.allSatisfy { $0.destination != "Barn" })
        #expect(barn.relationships.allSatisfy { $0.destination != "Client" })
    }

    @Test
    func inverseRelationshipsAreRegistered() throws {
        #expect(try relationship("Client", "horses").inverseName == "client")
        #expect(try relationship("Barn", "horses").inverseName == "currentBarn")
        #expect(try relationship("Barn", "appointments").inverseName == "barn")
        #expect(try relationship("Horse", "appointmentHorses").inverseName == "horse")
        #expect(try relationship("Appointment", "appointmentHorses").inverseName == "appointment")
    }

    @Test
    func domainRequiredToOneRelationshipsUseNullableStorage() throws {
        let relationships = try [
            relationship("Horse", "client"),
            relationship("Horse", "currentBarn"),
            relationship("Appointment", "barn"),
            relationship("AppointmentHorse", "appointment"),
            relationship("AppointmentHorse", "horse"),
        ]

        for relationship in relationships {
            #expect(relationship.minimumModelCount == nil)
            #expect(relationship.maximumModelCount == nil)
            #expect(relationship.deleteRule == .nullify)
        }
    }

    @Test
    func deleteRulesMatchTheFrozenMatrix() throws {
        #expect(try relationship("Client", "horses").deleteRule == .deny)
        #expect(try relationship("Barn", "horses").deleteRule == .deny)
        #expect(try relationship("Barn", "appointments").deleteRule == .deny)
        #expect(try relationship("Horse", "appointmentHorses").deleteRule == .deny)

        let appointmentHorses = try relationship("Appointment", "appointmentHorses")
        #expect(appointmentHorses.deleteRule == .cascade)
        #expect(appointmentHorses.minimumModelCount == 1)
    }

    @Test
    func horseDefaultsToSixWeeks() {
        let client = Client(name: "Alex Carter")
        let barn = Barn(name: "North Field")
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)

        #expect(horse.appointmentIntervalWeeks == 6)
    }

    @Test
    func appointmentDurationDefaultsToNil() {
        let barn = Barn(name: "North Field")
        let appointment = Appointment(startDate: .now, barn: barn)

        #expect(appointment.expectedDurationMinutes == nil)
    }

    private func relationship(
        _ entityName: String,
        _ propertyName: String
    ) throws -> Schema.Relationship {
        let entity = try #require(schema.entitiesByName[entityName])
        return try #require(entity.relationshipsByName[propertyName])
    }
}
