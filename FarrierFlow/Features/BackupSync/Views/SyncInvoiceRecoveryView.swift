import SwiftData
import SwiftUI

struct SyncInvoiceRecoveryView: View {
    @Environment(\.backupSync) private var backupSync
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var model: SyncInvoiceRecoveryModel?
    @State private var invoices: [InvoicePDFContent] = []
    @State private var settings: SyncRecoverySettingsChoice?
    @State private var failed = false
    @State private var confirms = false
    @State private var alert: FeatureAlert?

    var body: some View {
        Form {
            if failed {
                Text(BackupSyncCopy.invoiceRecoveryFailure)
                Button("Retry") { Task { await load() } }
            } else if let review = model?.review {
                Section {
                    Text(BackupSyncCopy.invoiceRecoveryExplanation)
                    Text(InvoiceHistoryCopy.notProtected).foregroundStyle(ColorTokens.textSecondary)
                }
                if !invoices.isEmpty {
                    Section {
                        ForEach(invoices, id: \.number) { InvoiceHistoryRow(content: $0) }
                    } header: { Text(InvoiceHistoryCopy.localOnly) }
                }
                Section {
                    DisclosureGroup(BackupSyncCopy.thisIPhone) { profile(review.localProfile) }
                    DisclosureGroup(BackupSyncCopy.cloudVersion) { profile(review.cloudProfile) }
                    Picker(selection: $settings) {
                        Text(BackupSyncCopy.chooseVersion).tag(Optional<SyncRecoverySettingsChoice>.none)
                        Text(BackupSyncCopy.keepLocalSettings).tag(Optional(SyncRecoverySettingsChoice.keepLocal))
                        Text(BackupSyncCopy.useCloudSettings).tag(Optional(SyncRecoverySettingsChoice.useCloud))
                    } label: { Text(BackupSyncCopy.recoverySettings) }
                    .pickerStyle(.inline)
                } footer: { Text(BackupSyncCopy.recoveryNumbering) }
                Section {
                    Button(BackupSyncCopy.invoiceRecoveryContinue) { confirms = true }
                        .disabled(settings == nil || model?.isBusy == true)
                        .accessibilityIdentifier("invoice-recovery-continue")
                    if model?.isBusy == true { ProgressView() }
                }
            } else { ProgressView(BackupSyncCopy.loadingReview) }
        }
        .farrierFlowScrollBackground()
        .navigationTitle(BackupSyncCopy.invoiceRecoveryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onDisappear { model?.cancel(); backupSync?.runtime?.finishRecoveryReview() }
        .confirmationDialog(BackupSyncCopy.invoiceRecoveryContinue, isPresented: $confirms, titleVisibility: .visible) {
            Button(BackupSyncCopy.invoiceRecoveryContinue, role: .destructive) { Task { await confirm() } }
            Button("Cancel", role: .cancel) { }
        } message: { Text(BackupSyncCopy.invoiceRecoveryConfirmation) }
        .alert(item: $alert) { Alert(title: Text($0.title), message: Text($0.message)) }
    }

    private func profile(_ record: SyncRecord) -> some View {
        ForEach(record.fields.keys.filter { $0 != "nextInvoiceNumber" }.sorted(), id: \.self) { key in
            LabeledContent {
                Text(SyncConflictPresentation.value(record.fields[key], key: key, record: record, graph: [], locale: locale))
            } label: { Text(SyncConflictPresentation.titles[key] ?? "Record Details") }
        }
    }

    private func load() async {
        failed = false
        settings = nil
        do {
            guard let backupSync, let account = backupSync.session?.accountID else { throw SyncJournalError.accountMismatch }
            if model == nil { model = try await backupSync.prepareInvoiceRecovery() }
            guard let model else { throw SyncJournalStoreError.unbound }
            try await model.load(accountID: account)
            invoices = []
            if let archive = model.review?.archive {
                let container = try SyncGraphCodec.readOnlyGraph(archive.records)
                for id in archive.invoiceIDs {
                    guard let invoice = try container.mainContext.fetch(FetchDescriptor<Invoice>()).first(where: { $0.syncID == id }) else {
                        throw InvoiceHistoryError.invoiceUnavailable
                    }
                    invoices.append(try InvoicePDFContentBuilder.build(invoice: invoice))
                }
            }
        } catch is CancellationError { }
        catch { failed = true }
    }

    private func confirm() async {
        guard let model, let settings, let account = backupSync?.session?.accountID else { failed = true; return }
        do {
            try await model.confirm(accountID: account, settings: settings)
            dismiss()
        } catch is CancellationError { }
        catch {
            alert = FeatureAlert(title: BackupSyncCopy.invoiceRecoveryTitle, message: BackupSyncCopy.invoiceRecoveryFailure)
            await load()
        }
    }
}
