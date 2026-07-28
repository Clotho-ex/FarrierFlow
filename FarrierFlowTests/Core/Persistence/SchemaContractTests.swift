import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("SwiftData schema contracts")
struct SchemaContractTests {
    private let v1Schema = Schema(versionedSchema: FarrierFlowSchemaV1.self)

    @Test
    func v1SchemaRegistersExactlyFiveModels() {
        let entityNames = Set(v1Schema.entities.map(\.name))

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
        let client = try #require(v1Schema.entitiesByName["Client"])
        let barn = try #require(v1Schema.entitiesByName["Barn"])

        #expect(client.relationships.allSatisfy { $0.destination != "Barn" })
        #expect(barn.relationships.allSatisfy { $0.destination != "Client" })
    }

    @Test
    func inverseRelationshipsAreRegistered() throws {
        #expect(try relationship(in: v1Schema, "Client", "horses").inverseName == "client")
        #expect(try relationship(in: v1Schema, "Barn", "horses").inverseName == "currentBarn")
        #expect(try relationship(in: v1Schema, "Barn", "appointments").inverseName == "barn")
        #expect(try relationship(in: v1Schema, "Horse", "appointmentHorses").inverseName == "horse")
        #expect(try relationship(in: v1Schema, "Appointment", "appointmentHorses").inverseName == "appointment")
    }

    @Test
    func domainRequiredToOneRelationshipsUseNullableStorage() throws {
        let relationships = try [
            relationship(in: v1Schema, "Horse", "client"),
            relationship(in: v1Schema, "Horse", "currentBarn"),
            relationship(in: v1Schema, "Appointment", "barn"),
            relationship(in: v1Schema, "AppointmentHorse", "appointment"),
            relationship(in: v1Schema, "AppointmentHorse", "horse"),
        ]

        for relationship in relationships {
            #expect(relationship.minimumModelCount == nil)
            #expect(relationship.maximumModelCount == nil)
            #expect(relationship.deleteRule == .nullify)
        }
    }

    @Test
    func deleteRulesMatchTheFrozenMatrix() throws {
        #expect(try relationship(in: v1Schema, "Client", "horses").deleteRule == .deny)
        #expect(try relationship(in: v1Schema, "Barn", "horses").deleteRule == .deny)
        #expect(try relationship(in: v1Schema, "Barn", "appointments").deleteRule == .deny)
        #expect(try relationship(in: v1Schema, "Horse", "appointmentHorses").deleteRule == .deny)

        let appointmentHorses = try relationship(
            in: v1Schema,
            "Appointment",
            "appointmentHorses"
        )
        #expect(appointmentHorses.deleteRule == .cascade)
        #expect(appointmentHorses.minimumModelCount == 1)
    }

    @Test
    func v2SchemaRegistersExactlySevenModels() {
        let schema = Schema(versionedSchema: FarrierFlowSchemaV2.self)

        #expect(Set(schema.entities.map(\.name)) == [
            "Client",
            "Barn",
            "Horse",
            "Appointment",
            "AppointmentHorse",
            "Visit",
            "VisitHorse",
        ])
    }

    @Test
    func v2VisitInverseRelationshipsAndDeleteRulesAreRegistered() throws {
        let schema = Schema(versionedSchema: FarrierFlowSchemaV2.self)

        let appointmentVisit = try relationship(in: schema, "Appointment", "visit")
        #expect(appointmentVisit.inverseName == "appointment")
        #expect(appointmentVisit.deleteRule == .deny)

        let barnVisits = try relationship(in: schema, "Barn", "visits")
        #expect(barnVisits.inverseName == "barn")
        #expect(barnVisits.deleteRule == .deny)

        let horseVisitHorses = try relationship(in: schema, "Horse", "visitHorses")
        #expect(horseVisitHorses.inverseName == "horse")
        #expect(horseVisitHorses.deleteRule == .deny)

        let visitHorses = try relationship(in: schema, "Visit", "visitHorses")
        #expect(visitHorses.inverseName == "visit")
        #expect(visitHorses.deleteRule == .cascade)

        let nullableStorageRelationships = try [
            relationship(in: schema, "Visit", "appointment"),
            relationship(in: schema, "Visit", "barn"),
            relationship(in: schema, "VisitHorse", "visit"),
            relationship(in: schema, "VisitHorse", "horse"),
        ]

        #expect(nullableStorageRelationships[0].inverseName == "visit")
        #expect(nullableStorageRelationships[1].inverseName == "visits")
        #expect(nullableStorageRelationships[2].inverseName == "visitHorses")
        #expect(nullableStorageRelationships[3].inverseName == "visitHorses")

        for relationship in nullableStorageRelationships {
            #expect(relationship.minimumModelCount == nil)
            #expect(relationship.maximumModelCount == nil)
            #expect(relationship.deleteRule == .nullify)
        }
    }

    @Test
    func v3SchemaRegistersExactlyEightModels() {
        let schema = Schema(versionedSchema: FarrierFlowSchemaV3.self)

        #expect(Set(schema.entities.map(\.name)) == [
            "Client",
            "Barn",
            "Horse",
            "Appointment",
            "AppointmentHorse",
            "Visit",
            "VisitHorse",
            "Photograph",
        ])
    }

    @Test
    func v3PhotographOwnershipAndDeleteRulesAreRegistered() throws {
        let schema = Schema(versionedSchema: FarrierFlowSchemaV3.self)

        let photographs = try relationship(in: schema, "VisitHorse", "photographs")
        #expect(photographs.inverseName == "visitHorse")
        #expect(photographs.deleteRule == .cascade)

        let visitHorse = try relationship(in: schema, "Photograph", "visitHorse")
        #expect(visitHorse.inverseName == "photographs")
        #expect(visitHorse.deleteRule == .nullify)
        #expect(visitHorse.minimumModelCount == nil)
        #expect(visitHorse.maximumModelCount == nil)
    }

    @Test
    func photographInitializerStoresApprovedMetadataAndOwnership() {
        let client = Client(name: "Alex Carter")
        let barn = Barn(name: "North Field")
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        let appointment = Appointment(startDate: .now, barn: barn)
        let visit = Visit(
            startedAt: .now,
            serviceLocationNameSnapshot: barn.name,
            appointment: appointment,
            barn: barn
        )
        let visitHorse = VisitHorse(visit: visit, horse: horse)
        let id = UUID(uuidString: "D4586522-AF85-4D45-826A-C4379B6DBD1E")!
        let createdAt = Date(timeIntervalSinceReferenceDate: 500)
        let photograph = Photograph(
            id: id,
            createdAt: createdAt,
            pixelWidth: 2_560,
            pixelHeight: 1_920,
            byteCount: 712_345,
            visitHorse: visitHorse
        )

        #expect(photograph.id == id)
        #expect(photograph.createdAt == createdAt)
        #expect(photograph.pixelWidth == 2_560)
        #expect(photograph.pixelHeight == 1_920)
        #expect(photograph.byteCount == 712_345)
        #expect(photograph.visitHorse === visitHorse)
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
        in schema: Schema,
        _ entityName: String,
        _ propertyName: String
    ) throws -> Schema.Relationship {
        let entity = try #require(schema.entitiesByName[entityName])
        return try #require(entity.relationshipsByName[propertyName])
    }
}
