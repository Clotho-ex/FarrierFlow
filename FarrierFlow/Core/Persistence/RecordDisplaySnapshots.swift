import Foundation
import SwiftData

// Views can outlive a save notification or navigation dismissal. Keep their
// displayed values independent of SwiftData objects that deletion invalidates.
struct HorseDetailSnapshot: Equatable, Identifiable {
    struct Reference: Equatable {
        let id: PersistentIdentifier
        let name: String
    }

    let id: PersistentIdentifier
    let name: String
    let client: Reference?
    let currentBarn: Reference?
    let appointmentIntervalWeeks: Int
    let safetyNotes: String?

    init(horse: Horse) {
        id = horse.persistentModelID
        name = horse.name
        client = horse.client.map { Reference(id: $0.persistentModelID, name: $0.name) }
        currentBarn = horse.currentBarn.map { Reference(id: $0.persistentModelID, name: $0.name) }
        appointmentIntervalWeeks = horse.appointmentIntervalWeeks
        safetyNotes = horse.safetyNotes
    }
}

struct ClientDetailSnapshot: Equatable, Identifiable {
    let id: PersistentIdentifier
    let name: String
    let phone: String?
    let email: String?
    let notes: String?
    let horses: [HorseDetailSnapshot]

    init(client: Client) {
        id = client.persistentModelID
        name = client.name
        phone = client.phone
        email = client.email
        notes = client.notes
        horses = client.horses.map(HorseDetailSnapshot.init)
    }
}

struct BarnDetailSnapshot: Equatable, Identifiable {
    let id: PersistentIdentifier
    let name: String
    let address: String?
    let contactNotes: String?
    let horses: [HorseDetailSnapshot]

    init(barn: Barn) {
        id = barn.persistentModelID
        name = barn.name
        address = barn.address
        contactNotes = barn.contactNotes
        horses = barn.horses.map(HorseDetailSnapshot.init)
    }
}

struct ServiceDetailSnapshot: Equatable, Identifiable {
    let id: PersistentIdentifier
    let name: String
    let defaultAmountMinorUnits: Int64
    let currencyCode: String
    let isArchived: Bool
    let horsesUsingAsDefault: [HorseDetailSnapshot]

    init(service: Service) {
        id = service.persistentModelID
        name = service.name
        defaultAmountMinorUnits = service.defaultAmountMinorUnits
        currencyCode = service.currencyCode
        isArchived = service.isArchived
        horsesUsingAsDefault = service.horsesUsingAsDefault.map(HorseDetailSnapshot.init)
    }
}
