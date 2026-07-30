import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("SwiftData schema contracts", .serialized)
struct SchemaContractTests {
    private let shippingSchema = Schema(versionedSchema: FarrierFlowSchemaV1.self)

    @Test
    func shippingSchemaRegistersExactlyFourteenModels() {
        #expect(Set(shippingSchema.entities.map(\.name)) == [
            "Client",
            "Barn",
            "Horse",
            "Appointment",
            "AppointmentHorse",
            "Visit",
            "VisitHorse",
            "Photograph",
            "Service",
            "WorkItem",
            "BusinessProfile",
            "Invoice",
            "InvoiceVisit",
            "InvoiceLineItem",
        ])
    }

    @Test
    func clientAndBarnRemainIndependent() throws {
        let client = try #require(shippingSchema.entitiesByName["Client"])
        let barn = try #require(shippingSchema.entitiesByName["Barn"])

        #expect(client.relationships.allSatisfy { $0.destination != "Barn" })
        #expect(barn.relationships.allSatisfy { $0.destination != "Client" })
    }

    @Test
    func existingProductInversesRemainRegistered() throws {
        #expect(try relationship("Client", "horses").inverseName == "client")
        #expect(try relationship("Barn", "horses").inverseName == "currentBarn")
        #expect(try relationship("Barn", "appointments").inverseName == "barn")
        #expect(try relationship("Barn", "visits").inverseName == "barn")
        #expect(try relationship("Horse", "appointmentHorses").inverseName == "horse")
        #expect(try relationship("Horse", "visitHorses").inverseName == "horse")
        #expect(try relationship("Appointment", "appointmentHorses").inverseName == "appointment")
        #expect(try relationship("Appointment", "visit").inverseName == "appointment")
        #expect(try relationship("Visit", "visitHorses").inverseName == "visit")
        #expect(try relationship("VisitHorse", "photographs").inverseName == "visitHorse")
        #expect(try relationship("VisitHorse", "workItems").inverseName == "visitHorse")
        #expect(try relationship("Service", "workItems").inverseName == "service")
        #expect(try relationship("Service", "horsesUsingAsDefault").inverseName == "defaultService")
    }

    @Test
    func invoiceInversesRepresentClientOwnershipAndSourceGrouping() throws {
        #expect(try relationship("Client", "invoices").inverseName == "client")
        #expect(try relationship("Invoice", "invoiceVisits").inverseName == "invoice")
        #expect(try relationship("Visit", "invoiceVisits").inverseName == "sourceVisit")
        #expect(try relationship("InvoiceVisit", "lineItems").inverseName == "invoiceVisit")
        #expect(try relationship("WorkItem", "invoiceLineItem").inverseName == "sourceWorkItem")

        let sourceVisit = try relationship("InvoiceVisit", "sourceVisit")
        #expect(sourceVisit.inverseName == "invoiceVisits")
        #expect(sourceVisit.deleteRule == .nullify)

        let sourceWorkItem = try relationship("InvoiceLineItem", "sourceWorkItem")
        #expect(sourceWorkItem.inverseName == "invoiceLineItem")
        #expect(sourceWorkItem.deleteRule == .nullify)
    }

    @Test
    func invoiceOwnsOnlyItsSnapshotGraph() throws {
        let invoices = try relationship("Client", "invoices")
        #expect(invoices.deleteRule == .deny)

        let visitInvoices = try relationship("Visit", "invoiceVisits")
        #expect(visitInvoices.deleteRule == .deny)

        let workItemInvoice = try relationship("WorkItem", "invoiceLineItem")
        #expect(workItemInvoice.deleteRule == .deny)

        let invoiceVisits = try relationship("Invoice", "invoiceVisits")
        #expect(invoiceVisits.deleteRule == .cascade)
        #expect(invoiceVisits.minimumModelCount == 1)

        let lineItems = try relationship("InvoiceVisit", "lineItems")
        #expect(lineItems.deleteRule == .cascade)
        #expect(lineItems.minimumModelCount == 1)
    }

    @Test
    func domainRequiredToOneRelationshipsUseNullableStorage() throws {
        let relationships = try [
            relationship("Horse", "client"),
            relationship("Horse", "currentBarn"),
            relationship("Appointment", "barn"),
            relationship("AppointmentHorse", "appointment"),
            relationship("AppointmentHorse", "horse"),
            relationship("Visit", "appointment"),
            relationship("Visit", "barn"),
            relationship("VisitHorse", "visit"),
            relationship("VisitHorse", "horse"),
            relationship("Photograph", "visitHorse"),
            relationship("WorkItem", "service"),
            relationship("WorkItem", "visitHorse"),
            relationship("Invoice", "client"),
            relationship("InvoiceVisit", "invoice"),
            relationship("InvoiceVisit", "sourceVisit"),
            relationship("InvoiceLineItem", "invoiceVisit"),
            relationship("InvoiceLineItem", "sourceWorkItem"),
        ]

        for relationship in relationships {
            #expect(relationship.minimumModelCount == nil)
            #expect(relationship.maximumModelCount == nil)
            #expect(relationship.deleteRule == .nullify)
        }
    }

    @Test
    func existingOwnershipAndDenyRulesRemainRegistered() throws {
        #expect(try relationship("Client", "horses").deleteRule == .deny)
        #expect(try relationship("Barn", "horses").deleteRule == .deny)
        #expect(try relationship("Barn", "appointments").deleteRule == .deny)
        #expect(try relationship("Barn", "visits").deleteRule == .deny)
        #expect(try relationship("Horse", "appointmentHorses").deleteRule == .deny)
        #expect(try relationship("Horse", "visitHorses").deleteRule == .deny)
        #expect(try relationship("Appointment", "visit").deleteRule == .deny)
        #expect(try relationship("Service", "workItems").deleteRule == .deny)

        let appointmentHorses = try relationship("Appointment", "appointmentHorses")
        #expect(appointmentHorses.deleteRule == .cascade)
        #expect(appointmentHorses.minimumModelCount == 1)

        let visitHorses = try relationship("Visit", "visitHorses")
        #expect(visitHorses.deleteRule == .cascade)
        #expect(visitHorses.minimumModelCount == 1)

        #expect(try relationship("VisitHorse", "photographs").deleteRule == .cascade)
        #expect(try relationship("VisitHorse", "workItems").deleteRule == .cascade)
    }

    @Test
    func existingInitializerDefaultsRemainStable() {
        let client = Client(name: "Alex Carter")
        let barn = Barn(name: "North Field")
        let horse = Horse(name: "Milo", client: client, currentBarn: barn)
        let appointment = Appointment(startDate: .now, barn: barn)
        let profile = BusinessProfile(name: "Alex Carter Farrier")

        #expect(horse.appointmentIntervalWeeks == 6)
        #expect(appointment.expectedDurationMinutes == nil)
        #expect(profile.nextInvoiceNumber == 1)
    }

    private func relationship(
        _ entityName: String,
        _ propertyName: String
    ) throws -> Schema.Relationship {
        let entity = try #require(shippingSchema.entitiesByName[entityName])
        return try #require(entity.relationshipsByName[propertyName])
    }
}
