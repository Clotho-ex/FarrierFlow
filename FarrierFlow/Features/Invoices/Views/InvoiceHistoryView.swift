import SwiftData
import SwiftUI

enum InvoiceHistoryRoute: Hashable { case list, detail(InvoiceHistoryIdentity) }

// A standalone native stack avoids iOS 18's deep-stack collection layout loop.
struct InvoiceHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let container: ModelContainer
    var body: some View {
        NavigationStack {
            InvoiceHistoryView(container: container)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .navigationDestination(for: InvoiceHistoryRoute.self) { route in
                    switch route {
                    case .list: InvoiceHistoryView(container: container)
                    case .detail(let identity): InvoiceHistoryDetailView(identity: identity, container: container)
                    }
                }
        }
    }
}

struct InvoiceHistoryView: View {
    @State private var model: InvoiceHistoryModel
    @State private var failed = false

    init(container: ModelContainer) {
        _model = State(initialValue: InvoiceHistoryModel(container: container))
    }

    var body: some View {
        List {
            Section { explanation }
            historyRecords
        }
        .farrierFlowScrollBackground()
        .navigationTitle(InvoiceHistoryCopy.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
    }

    private var explanation: some View {
        Text(InvoiceHistoryCopy.explanation).accessibilityIdentifier("invoice-history-explanation")
    }

    @ViewBuilder
    private var historyRecords: some View {
        if failed {
            Text(InvoiceHistoryCopy.failure)
            Button("Retry", action: reload)
        } else if model.summaries.isEmpty {
            Text(InvoiceHistoryCopy.empty)
        } else {
            ForEach(model.summaries) { summary in
                NavigationLink(value: InvoiceHistoryRoute.detail(summary.id)) {
                    InvoiceHistoryRow(content: summary.content)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("invoice-history-row-" + summary.id.invoiceID.uuidString)
            }
        }
    }

    private func reload() {
        do { try model.load(); failed = false }
        catch { failed = true }
    }
}

struct InvoiceHistoryRow: View {
    @Environment(\.locale) private var locale
    let content: InvoicePDFContent
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tight) {
            Text("Invoice \(content.number)").font(.headline)
            Text(content.clientName)
            Text(content.invoiceDate, format: .dateTime.month(.abbreviated).day().year())
                .foregroundStyle(ColorTokens.textSecondary)
            Text(MoneyFormatter.currency(minorUnits: content.totalMinorUnits,
                currencyCode: content.currencyCode, locale: locale) ?? "—")
            Text(content.status.displayName).foregroundStyle(ColorTokens.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HistoryVisitSection: Identifiable {
    let id: String
    let content: InvoicePDFContent.VisitGroup
}

private struct HistoryLineRow: Identifiable {
    let id: String
    let content: InvoicePDFContent.LineItem
}

private struct InvoiceHistoryShare: Identifiable {
    let url: URL
    var id: URL { url }
}

struct InvoiceHistoryDetailView: View {
    @Environment(\.locale) private var locale
    @State private var model: InvoiceHistoryModel
    @State private var content: InvoicePDFContent?
    @State private var failed = false
    @State private var exportTask: Task<Void, Never>?
    let identity: InvoiceHistoryIdentity

    init(identity: InvoiceHistoryIdentity, container: ModelContainer) {
        self.identity = identity
        _model = State(initialValue: InvoiceHistoryModel(container: container))
    }

    var body: some View {
        Form {
            Section {
                Text(InvoiceHistoryCopy.notProtected)
                Text(InvoiceHistoryCopy.explanation)
            }
            if let content {
                Section {
                    InvoiceHistoryRow(content: content)
                    LabeledContent("Business", value: content.businessName)
                    if let value = content.businessPhone { LabeledContent("Phone", value: value) }
                    if let value = content.businessEmail { LabeledContent("Email", value: value) }
                    if let value = content.businessAddress { Text(value) }
                    if let value = content.clientPhone { LabeledContent("Client Phone", value: value) }
                    if let value = content.clientEmail { LabeledContent("Client Email", value: value) }
                    if let value = content.dueDate { LabeledContent("Due Date") { Text(value, style: .date) } }
                }
                ForEach(visitSections(content)) { section in
                    let visit = section.content
                    Section {
                        Text(visit.date, style: .date)
                        Text(visit.location)
                        if let address = visit.address { Text(address) }
                        ForEach(lineRows(section)) { row in
                            let line = row.content
                            VStack(alignment: .leading) {
                                Text(line.horseName).font(.headline)
                                Text(line.serviceName)
                                Text(amount(line.amountMinorUnits, currency: content.currencyCode))
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                if let payment = content.payment {
                    Section("Payment") {
                        Text(amount(payment.amountMinorUnits, currency: content.currencyCode))
                        Text(payment.receivedAt, style: .date)
                        Text(payment.method.displayName)
                        if let value = payment.otherDescription { Text(value) }
                        if let value = payment.reference { Text(value) }
                    }
                }
                if let note = content.note { Section("Note") { Text(note) } }
                Section {
                    Button("Share Invoice", systemImage: "square.and.arrow.up") {
                        exportTask = Task { await model.preparePDF(archiveID: identity.archiveID, invoiceID: identity.invoiceID) }
                    }
                    .disabled(model.isPreparing)
                    .accessibilityIdentifier("invoice-history-share")
                    if model.isPreparing { ProgressView("Preparing PDF…") }
                }
            } else if failed {
                Text(InvoiceHistoryCopy.failure)
                Button("Retry", action: reload)
            } else { ProgressView("Loading Invoice…") }
        }
        .farrierFlowScrollBackground()
        .navigationTitle(content.map { String(localized: "Invoice \($0.number)", locale: locale) } ?? String(localized: InvoiceHistoryCopy.title))
        .navigationBarTitleDisplayMode(.inline)
        .task { reload() }
        .sheet(item: Binding(get: { model.shareURL.map { InvoiceHistoryShare(url: $0) } },
            set: { if $0 == nil { model.sharingCompleted() } }), onDismiss: model.sharingCompleted) { share in
                InvoiceShareSheet(url: share.url) { _ in model.sharingCompleted() }
            }
        .alert(item: $model.alert) { Alert(title: Text($0.title), message: Text($0.message)) }
        .onDisappear { exportTask?.cancel(); model.sharingCompleted() }
    }

    private func reload() {
        do {
            content = try model.content(for: identity)
            failed = false
        } catch { failed = true }
    }

    // Snapshot positions are immutable within an archive. Prefixing by invoice
    // identity keeps their row identity stable without inventing financial UUIDs.
    private func visitSections(_ content: InvoicePDFContent) -> [HistoryVisitSection] {
        content.visits.enumerated().map { index, visit in
            .init(id: "\(identity.archiveID)/\(identity.invoiceID)/visit/\(index)", content: visit)
        }
    }

    private func lineRows(_ section: HistoryVisitSection) -> [HistoryLineRow] {
        section.content.lineItems.enumerated().map { index, line in
            .init(id: "\(section.id)/line/\(index)", content: line)
        }
    }

    private func amount(_ value: Int64, currency: String) -> String {
        MoneyFormatter.currency(minorUnits: value, currencyCode: currency, locale: locale) ?? "—"
    }
}
