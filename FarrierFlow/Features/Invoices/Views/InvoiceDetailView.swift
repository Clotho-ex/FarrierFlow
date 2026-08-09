import SwiftData
import SwiftUI

struct InvoiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(PersistenceMutationCoordinator.self) private var mutationCoordinator
    @State private var model: InvoiceDetailModel
    @State private var showsPaidConfirmation = false
    @State private var showsDeleteConfirmation = false
    @State private var shareModel = InvoicePDFShareModel()
    @State private var pdfPreparationTask: Task<Void, Never>?

    let invoiceID: PersistentIdentifier

    init(invoiceID: PersistentIdentifier) {
        self.invoiceID = invoiceID
        _model = State(initialValue: InvoiceDetailModel(invoiceID: invoiceID))
    }

    var body: some View {
        Group {
            switch model.loadState {
            case .loading:
                ProgressView("Loading Invoice…")
            case .failed:
                ContentUnavailableView {
                    Label("Invoice Unavailable", systemImage: "exclamationmark.circle")
                } description: {
                    Text("FarrierFlow couldn’t load this invoice. Try again.")
                } actions: {
                    Button("Retry", action: reload)
                }
            case .loaded:
                if let detail = model.detail {
                    detailList(detail)
                }
            }
        }
        .navigationTitle(model.detail.map { "Invoice \($0.number)" } ?? "Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if shareModel.isPreparing {
                HStack(spacing: SpacingTokens.rowContent) {
                    ProgressView()
                    Text("Preparing PDF…")
                        .font(.callout.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.bar)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("invoice-pdf-preparing-status")
            }
        }
        .toolbar {
            if model.canMarkPaid {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark Paid", systemImage: "checkmark.circle") {
                        showsPaidConfirmation = true
                    }
                    .accessibilityIdentifier("invoice-mark-paid-action")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    preparePDF()
                } label: {
                    if shareModel.isPreparing {
                        ProgressView()
                            .accessibilityLabel("Preparing PDF…")
                    } else {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                    }
                }
                .disabled(shareModel.isPreparing)
                .accessibilityIdentifier("invoice-share-pdf-action")
            }
            if model.canDelete {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("More", systemImage: "ellipsis.circle") {
                        Button("Delete Invoice", systemImage: "trash", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                        .accessibilityIdentifier("invoice-delete-action")
                    }
                    .accessibilityIdentifier("invoice-more-actions")
                }
            }
        }
        .confirmationDialog("Mark Invoice Paid?", isPresented: $showsPaidConfirmation, titleVisibility: .visible) {
            Button("Mark Paid") {
                model.markPaid(in: context, coordinator: mutationCoordinator)
            }
            .accessibilityIdentifier("invoice-mark-paid-confirmation")
        } message: {
            Text("This records today’s payment date and cannot be undone.")
        }
        .confirmationDialog("Delete Invoice?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete Invoice", role: .destructive) {
                model.delete(in: context, coordinator: mutationCoordinator)
                if model.didDelete { dismiss() }
            }
            .accessibilityIdentifier("invoice-delete-confirmation")
        } message: {
            Text("Recorded work stays in FarrierFlow and can be added to another invoice.")
        }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
        .alert(item: $shareModel.alert) {
            Alert(
                title: Text($0.title),
                message: Text($0.message),
                primaryButton: .default(Text("Retry")) {
                    preparePDF(isRetry: true)
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
        .sheet(isPresented: Binding(
            get: { shareModel.shareURL != nil },
            set: { if !$0 { shareModel.sharingCompleted() } }
        )) {
            if let url = shareModel.shareURL {
                InvoiceShareSheet(url: url) { shareModel.sharingCompleted() }
            }
        }
        .task(id: invoiceID, reload)
        .onDisappear(perform: cancelPDFPreparation)
    }

    private func detailList(_ detail: InvoiceDetail) -> some View {
        List {
            Section("Invoice") {
                LabeledContent("Invoice Number", value: detail.number)
                LabeledContent("Status", value: detail.status == .paid ? "Paid" : "Unpaid")
                LabeledContent("Invoice Date", value: formattedDate(detail.invoiceDate))
                if let dueDate = detail.dueDate {
                    LabeledContent("Due Date", value: formattedDate(dueDate))
                }
                if let paidAt = detail.paidAt {
                    LabeledContent("Payment Date", value: formattedDate(paidAt))
                }
                LabeledContent("Total", value: formattedTotal(detail.total))
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("invoice-detail-total")
            }
            ForEach(detail.visits) { visit in
                Section {
                    ForEach(visit.lineItems) { lineItem in
                        InvoiceLineItemRow(lineItem: lineItem)
                    }
                } header: {
                    VStack(alignment: .leading) {
                        Text(visit.visitDate, format: .dateTime.month(.abbreviated).day().year())
                        Text(visit.serviceLocationName)
                    }
                }
            }
            if let note = detail.note {
                Section("Note") { Text(note) }
            }
            Section("Business") {
                snapshotContact(name: detail.businessName, phone: detail.businessPhone, email: detail.businessEmail, address: detail.businessAddress)
            }
            Section("Client") {
                snapshotContact(name: detail.clientName, phone: detail.clientPhone, email: detail.clientEmail, address: nil)
            }
        }
        .accessibilityIdentifier("invoice-detail-\(detail.number)")
    }

    @ViewBuilder
    private func snapshotContact(name: String, phone: String?, email: String?, address: String?) -> some View {
        Text(name)
        if let phone { LabeledContent("Phone", value: phone) }
        if let email { LabeledContent("Email", value: email) }
        if let address { LabeledContent("Address", value: address) }
    }

    private func formattedTotal(_ total: MoneyAvailability) -> String {
        switch total {
        case .available(let amount):
            MoneyFormatter.usd(minorUnits: amount, locale: locale)
                ?? String(localized: "Unavailable", locale: locale)
        case .unavailable:
            String(localized: "Unavailable", locale: locale)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(
            .dateTime.month(.abbreviated).day().year().locale(locale)
        )
    }

    private func reload() {
        model.load(in: context, locale: locale)
    }

    private func preparePDF(isRetry: Bool = false) {
        pdfPreparationTask?.cancel()
        pdfPreparationTask = Task {
            if isRetry {
                await shareModel.retry(invoiceID: invoiceID, in: context)
            } else {
                await shareModel.prepare(invoiceID: invoiceID, in: context)
            }
            pdfPreparationTask = nil
        }
    }

    private func cancelPDFPreparation() {
        pdfPreparationTask?.cancel()
        pdfPreparationTask = nil
        shareModel.sharingCompleted()
    }
}
