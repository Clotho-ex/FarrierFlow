import SwiftData
import SwiftUI

enum SyncReviewRoute: Hashable { case review, invoiceRecovery }

// The legacy presentation shares the same review model and atomic save path.
struct SyncConflictReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let container: ModelContainer
    var body: some View {
        NavigationStack {
            SyncConflictReviewView(container: container)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .navigationDestination(for: SyncReviewRoute.self) { route in
                    switch route {
                    case .review: SyncConflictReviewView(container: container)
                    case .invoiceRecovery: SyncInvoiceRecoveryView()
                    }
                }
        }
    }
}

struct SyncConflictReviewView: View {
    @Environment(\.backupSync) private var backupSync
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var model: SyncConflictModel
    @State private var choices: [UUID: SyncConflictChoice] = [:]
    @State private var loadFailed = false
    @State private var confirmsChoices = false
    @State private var alert: FeatureAlert?

    init(container: ModelContainer) {
        _model = State(initialValue: SyncConflictModel(container: container))
    }

    var body: some View {
        Form {
            if loadFailed {
                Text(BackupSyncCopy.reviewFailure)
                Button("Retry", action: reload)
            } else if model.needsInvoiceRecovery {
                Text(BackupSyncCopy.relatedReview)
                NavigationLink(value: SyncReviewRoute.invoiceRecovery) { Text(BackupSyncCopy.invoiceRecoveryTitle) }
                    .accessibilityIdentifier("backup-sync-invoice-recovery")
            } else if model.conflicts.isEmpty && model.deferredRemote == nil {
                Text(BackupSyncCopy.noConflicts)
            } else {
                Section { Text(BackupSyncCopy.reviewExplanation) }
                if !model.relatedChanges.isEmpty {
                    Section {
                        Text(BackupSyncCopy.relatedChangesExplanation)
                        ForEach(model.relatedChanges) { change in
                            DisclosureGroup {
                                ForEach(model.changedFields(in: change), id: \.self) { field in
                                    LabeledContent {
                                        Text(model.value(in: change, field: field, cloud: true, locale: locale))
                                    } label: { Text(SyncConflictPresentation.titles[field] ?? "Record Details") }
                                }
                            } label: { Text(change.kind.localizedTitle) }
                        }
                    } header: { Text(BackupSyncCopy.relatedChangesTitle) }
                }
                ForEach(model.conflicts) { conflict in
                    Section {
                        ForEach(model.changedFields(in: conflict), id: \.self) { field in
                            DisclosureGroup {
                                LabeledContent {
                                    Text(model.value(in: conflict, field: field, cloud: false, locale: locale))
                                } label: { Text(BackupSyncCopy.thisIPhone) }
                                LabeledContent {
                                    Text(model.value(in: conflict, field: field, cloud: true, locale: locale))
                                } label: { Text(BackupSyncCopy.cloudVersion) }
                            } label: { Text(SyncConflictPresentation.titles[field] ?? "Record Details") }
                        }
                        Picker(selection: Binding<SyncConflictChoice?>(
                            get: { choices[conflict.id] }, set: { choices[conflict.id] = $0 }
                        )) {
                            Text(BackupSyncCopy.chooseVersion).tag(Optional<SyncConflictChoice>.none)
                            if conflict.remote != nil {
                                Text(BackupSyncCopy.keepIPhone).tag(Optional(SyncConflictChoice.keepIPhone))
                            }
                            Text(BackupSyncCopy.useCloud).tag(Optional(SyncConflictChoice.useCloud))
                        } label: { Text(BackupSyncCopy.keepVersion) }
                        .pickerStyle(.inline)
                        DisclosureGroup("Record ID") { Text(conflict.id.uuidString).textSelection(.enabled) }
                    } header: { Text(conflict.kind.localizedTitle) }
                }
                Section {
                    Button(BackupSyncCopy.applyChoices) { confirmsChoices = true }
                        .disabled(choices.count != model.conflicts.count)
                }
            }
        }
        .farrierFlowScrollBackground()
        .navigationTitle(BackupSyncCopy.reviewTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .confirmationDialog(BackupSyncCopy.applyChoices, isPresented: $confirmsChoices, titleVisibility: .visible) {
            Button(BackupSyncCopy.applyChoices, role: .destructive, action: apply)
        } message: { Text(BackupSyncCopy.reviewConfirmation) }
        .alert(item: $alert) { Alert(title: Text($0.title), message: Text($0.message)) }
    }

    private func reload() {
        guard let account = backupSync?.session?.accountID else { loadFailed = true; return }
        do { try model.load(accountID: account); choices = [:]; loadFailed = false }
        catch { loadFailed = true }
    }

    private func apply() {
        guard let account = backupSync?.session?.accountID else { loadFailed = true; return }
        do {
            try model.resolve(choices, accountID: account)
            backupSync?.runtime?.requestSync()
            dismiss()
        } catch {
            alert = FeatureAlert(title: BackupSyncCopy.reviewTitle, message: BackupSyncCopy.reviewFailure)
            reload()
        }
    }
}
