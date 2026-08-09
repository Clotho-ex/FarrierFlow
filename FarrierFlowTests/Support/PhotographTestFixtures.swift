import CoreGraphics
import Foundation
import ImageIO
import SwiftData
import Testing
import UniformTypeIdentifiers
@testable import FarrierFlow

@MainActor
enum PhotographTestFixtures {
    struct VisitGraph {
        let container: ModelContainer
        let visitID: PersistentIdentifier
        let visitHorseIDs: [PersistentIdentifier]

        var visitHorseID: PersistentIdentifier {
            visitHorseIDs[0]
        }
    }

    static func makeVisitGraph(
        completedAt: Date? = nil,
        horseCount: Int = 1
    ) throws -> VisitGraph {
        precondition(horseCount > 0)
        let container = try ModelContainerFactory.inMemoryTest()
        let context = container.mainContext
        let client = Client(name: "Alex")
        let barn = Barn(name: "North Field")
        context.insert(client)
        context.insert(barn)
        let horses = (0..<horseCount).map { index in
            Horse(
                name: index == 0 ? "Milo" : "Horse \(index + 1)",
                client: client,
                currentBarn: barn
            )
        }
        for horse in horses {
            context.insert(horse)
            client.horses.append(horse)
            barn.horses.append(horse)
        }
        let appointment = ModelFixtures.makeAppointment(
            barn: barn,
            horses: horses,
            in: context
        )
        let visit = ModelFixtures.makeVisit(
            completedAt: completedAt,
            appointment: appointment,
            in: context
        )
        if completedAt != nil {
            let servicedVisitHorse = visit.visitHorses[0]
            servicedVisitHorse.outcomeRawValue = VisitOutcome.serviced.rawValue
            let service = ModelFixtures.makeService(in: context)
            _ = ModelFixtures.makeWorkItem(
                service: service,
                visitHorse: servicedVisitHorse,
                in: context
            )
            for visitHorse in visit.visitHorses.dropFirst() {
                visitHorse.outcomeRawValue = VisitOutcome.notServiced.rawValue
            }
        }
        try DomainGraphValidator.save(context)
        return VisitGraph(
            container: container,
            visitID: visit.persistentModelID,
            visitHorseIDs: visit.visitHorses.map(\.persistentModelID)
        )
    }

    static func makeLibrary(
        graph: VisitGraph,
        rootURL: URL,
        fileStore: PhotographFileStore? = nil,
        normalizer: PhotographNormalizer = PhotographNormalizer(),
        mutationCoordinator: PersistenceMutationCoordinator = PersistenceMutationCoordinator(),
        coordinator: PhotographStorageCoordinator = PhotographStorageCoordinator(),
        protectedDataAvailable: @escaping @MainActor () -> Bool = { true },
        saving: @escaping @MainActor (ModelContext) throws -> Void = {
            try DomainGraphValidator.save($0)
        },
        discarding: @escaping @MainActor (Visit, ModelContext) throws -> Void = {
            try RecordDeletionRules.delete($0, in: $1)
        },
        hooks: PhotographOperationHooks = .production
    ) -> PhotographLibrary {
        PhotographLibrary(
            container: graph.container,
            mutationCoordinator: mutationCoordinator,
            fileStore: fileStore ?? PhotographFileStore(rootURL: rootURL),
            normalizer: normalizer,
            coordinator: coordinator,
            protectedDataAvailable: protectedDataAvailable,
            saving: saving,
            discarding: discarding,
            hooks: hooks
        )
    }

    nonisolated static func jpeg(
        width: Int = 80,
        height: Int = 60,
        quality: Double = 0.95,
        detailed: Bool = false
    ) throws -> Data {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(
            CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
                    | CGBitmapInfo.byteOrder32Big.rawValue
            )
        )
        if detailed {
            let tileSize = 8
            for y in stride(from: 0, to: height, by: tileSize) {
                for x in stride(from: 0, to: width, by: tileSize) {
                    let value = (x * 31 + y * 17) % 255
                    context.setFillColor(
                        CGColor(
                            red: CGFloat(value) / 255,
                            green: CGFloat((value * 3) % 255) / 255,
                            blue: CGFloat((value * 7) % 255) / 255,
                            alpha: 1
                        )
                    )
                    context.fill(
                        CGRect(x: x, y: y, width: tileSize, height: tileSize)
                    )
                }
            }
        } else {
            context.setFillColor(CGColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(
            CGImageDestinationCreateWithData(
                data,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        )
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
