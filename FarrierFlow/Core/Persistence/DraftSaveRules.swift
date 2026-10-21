import Foundation

nonisolated enum DraftSaveError: Error { case changedSinceEditing }

nonisolated enum DraftSaveRules {
    static func merge<Value: Equatable>(original: Value, proposed: Value, current: Value) throws -> Value {
        if proposed == original { return current }
        guard current == original || proposed == current else { throw DraftSaveError.changedSinceEditing }
        return proposed
    }

    static func mergeFields<Draft>(original: Draft, proposed: Draft, current: Draft,
                                   fields: [WritableKeyPath<Draft, String>]) throws -> Draft {
        var result = current
        for field in fields {
            result[keyPath: field] = try merge(original: original[keyPath: field],
                proposed: proposed[keyPath: field], current: current[keyPath: field])
        }
        return result
    }

    static var changedAlert: FeatureAlert {
        FeatureAlert(
            title: LocalizedStringResource("editor.recordChanged.title", defaultValue: "Record Changed"),
            message: LocalizedStringResource("editor.recordChanged.message", defaultValue:
                "This record changed while this form was open. Your draft is still here. Close this form and reopen the record to review the latest details before saving.")
        )
    }
}
