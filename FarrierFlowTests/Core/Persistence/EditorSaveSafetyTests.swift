import Foundation
import SwiftData
import Testing
@testable import FarrierFlow

@Suite("Open editors preserve newer stored values")
@MainActor
struct EditorSaveSafetyTests {
    @Test(arguments: ["barn", "horse", "service", "appointment", "profile", "visit"])
    func staleFormsCannotOverwriteNewerChanges(kind: String) throws {
        let f = try InvoiceActionGraph.make()
        switch kind {
        case "barn":
            let record = try #require(f.context.fetch(FetchDescriptor<Barn>()).first)
            let editor = BarnEditorModel(barn: record)
            editor.draft.name = "Local name"
            record.name = "Remote name"
            try f.context.save()
            #expect(editor.save(in: f.context) == nil)
            #expect(record.name == "Remote name")
        case "horse":
            let record = try #require(f.context.fetch(FetchDescriptor<Horse>()).first)
            let editor = HorseEditorModel(horse: record)
            editor.loadChoices(in: f.context)
            editor.draft.name = "Local name"
            record.name = "Remote name"
            try f.context.save()
            #expect(editor.save(in: f.context) == nil)
            #expect(record.name == "Remote name")
        case "service":
            let record = try #require(f.context.fetch(FetchDescriptor<Service>()).first)
            let editor = ServiceEditorModel(service: record)
            editor.loadBusinessCurrency(in: f.context)
            editor.draft.name = "Local name"
            record.name = "Remote name"
            try f.context.save()
            #expect(editor.save(in: f.context) == nil)
            #expect(record.name == "Remote name")
        case "appointment":
            let record = try #require(f.context.fetch(FetchDescriptor<Appointment>()).first)
            let editor = AppointmentEditorModel(appointment: record)
            editor.load(in: f.context)
            editor.draft.notes = "Local notes"
            record.notes = "Remote notes"
            try f.context.save()
            #expect(editor.save(in: f.context) == nil)
            #expect(record.notes == "Remote notes")
        case "profile":
            let record = try #require(f.context.fetch(FetchDescriptor<BusinessProfile>()).first)
            let editor = BusinessProfileEditorModel()
            editor.load(in: f.context)
            editor.draft.name = "Local name"
            record.name = "Remote name"
            try f.context.save()
            #expect(!editor.save(in: f.context))
            #expect(record.name == "Remote name")
        default:
            let editor = VisitEditorModel(visitID: f.visitID, in: f.container, mode: .correction)
            editor.load()
            editor.draft?.horses[0].workNotes = "Local notes"
            let member = try #require(f.context.fetch(FetchDescriptor<VisitHorse>()).first)
            member.workNotes = "Remote notes"
            try f.context.save()
            #expect(!editor.saveCorrection())
            #expect(try ModelContext(f.container).fetch(FetchDescriptor<VisitHorse>()).first?.workNotes == "Remote notes")
        }
    }
}
