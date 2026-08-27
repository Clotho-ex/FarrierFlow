import SwiftData
import SwiftUI

private enum InvoiceActionConfirmation {
    case markPaid
    case delete
}

struct InvoiceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model: InvoiceDetailModel
    @State private var actionConfirmation: InvoiceActionConfirmation?
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
            ToolbarItem(placement: .topBarTrailing) {
                Menu("Invoice Actions", systemImage: "ellipsis.circle") {
                    Button("Share Invoice", systemImage: "square.and.arrow.up") {
                        preparePDF()
                    }
                    .disabled(shareModel.isPreparing)
                    .accessibilityIdentifier("invoice-share-pdf-action")

                    if subscription.allowsMutations, model.canMarkPaid {
                        Button("Mark Paid", systemImage: "checkmark.circle") {
                            actionConfirmation = .markPaid
                        }
                        .accessibilityIdentifier("invoice-mark-paid-action")
                    }

                    if subscription.allowsMutations, model.canDelete {
                        Divider()
                        Button("Delete Invoice", systemImage: "trash", role: .destructive) {
                            actionConfirmation = .delete
                        }
                        .accessibilityIdentifier("invoice-delete-action")
                    }
                }
                .accessibilityIdentifier("invoice-actions-menu")
                .alert(
                    actionConfirmationTitle,
                    isPresented: actionConfirmationPresented,
                    presenting: actionConfirmation
                ) { confirmation in
                    switch confirmation {
                    case .markPaid:
                        Button("Mark Paid") {
                            guard subscription.allowsMutations else { return }
                            model.markPaid(in: context)
                        }
                        .accessibilityIdentifier("invoice-mark-paid-confirmation")
                        Button("Cancel", role: .cancel) { }
                    case .delete:
                        Button("Delete Invoice", role: .destructive) {
                            guard subscription.allowsMutations else { return }
                            model.delete(in: context)
                            if model.didDelete { dismiss() }
                        }
                        .accessibilityIdentifier("invoice-delete-confirmation")
                        Button("Cancel", role: .cancel) { }
                    }
                } message: { confirmation in
                    switch confirmation {
                    case .markPaid:
                        Text("This records today’s payment date and cannot be undone.")
                    case .delete:
                        Text("Recorded work stays in FarrierFlow and can be added to another invoice.")
                    }
                }
            }
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
        .sheet(isPresented: shareSheetPresented) {
            if let url = shareModel.shareURL {
                InvoiceShareSheet(url: url) {
                    shareModel.sharingCompleted()
                }
            }
        }
        .task(id: invoiceID, reload)
        .onDisappear(perform: cancelPDFPreparation)
    }

    private func detailList(_ detail: InvoiceDetail) -> some View {
        let amount = formattedTotal(detail.total)

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 36) {
                InvoiceDetailHeader(
                    number: detail.number,
                    businessName: detail.businessName,
                    status: detail.status,
                    amount: amount
                )
                InvoiceMetadataSection(
                    invoiceDate: detail.invoiceDate,
                    dueDate: detail.dueDate,
                    paidAt: detail.paidAt,
                    locale: locale
                )
                InvoiceContactSection(
                    title: "Bill To",
                    name: detail.clientName,
                    phone: detail.clientPhone,
                    email: detail.clientEmail,
                    address: nil
                )
                ForEach(detail.visits) { visit in
                    InvoiceVisitSection(visit: visit)
                }
                InvoiceDetailTotal(
                    status: detail.status,
                    amount: amount
                )
                if let note = detail.note {
                    InvoiceTextSection(title: "Note", text: note)
                }
                InvoiceContactSection(
                    title: "From",
                    name: detail.businessName,
                    phone: detail.businessPhone,
                    email: detail.businessEmail,
                    address: detail.businessAddress
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
            .accessibilityIdentifier("invoice-native-detail-content")
        }
        .background(Color(uiColor: .systemBackground))
        .accessibilityIdentifier("invoice-detail-\(detail.number)")
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

    private var shareSheetPresented: Binding<Bool> {
        Binding(
            get: { shareModel.shareURL != nil },
            set: { isPresented in
                if !isPresented {
                    shareModel.sharingCompleted()
                }
            }
        )
    }

    private var actionConfirmationPresented: Binding<Bool> {
        Binding(
            get: { actionConfirmation != nil },
            set: { isPresented in
                if !isPresented {
                    actionConfirmation = nil
                }
            }
        )
    }

    private var actionConfirmationTitle: LocalizedStringKey {
        switch actionConfirmation {
        case .markPaid:
            "Mark Invoice Paid?"
        case .delete:
            "Delete Invoice?"
        case nil:
            "Invoice Actions"
        }
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

private struct InvoiceDetailHeader: View {
    let number: String
    let businessName: String
    let status: InvoiceStatus
    let amount: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                identity
                amountSummary
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 20) {
                identity
                amountSummary
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.bottom, SpacingTokens.rowContent)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(businessName)
                .font(.title2.weight(.semibold))
            Text("Invoice \(number)")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.fill.tertiary, in: Capsule())
                .accessibilityLabel("Status, \(statusText)")
        }
    }

    private var amountSummary: some View {
        VStack(alignment: .trailing, spacing: SpacingTokens.rowContent) {
            Text(amount)
                .font(.largeTitle.weight(.bold))
                .monospacedDigit()
                .accessibilityIdentifier("invoice-detail-total")
            Text(amountLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            status == .unpaid ? "invoice-detail-amount-due" : "invoice-detail-invoice-total"
        )
    }

    private var statusText: String {
        status == .paid ? String(localized: "Paid") : String(localized: "Unpaid")
    }

    private var amountLabel: LocalizedStringKey {
        status == .unpaid ? "Amount Due" : "Invoice Total"
    }
}

private struct InvoiceMetadataSection: View {
    let invoiceDate: Date
    let dueDate: Date?
    let paidAt: Date?
    let locale: Locale

    var body: some View {
        VStack(spacing: SpacingTokens.rowContent) {
            metadataRow("Invoice Date", date: invoiceDate)
            if let dueDate {
                Divider()
                metadataRow("Due Date", date: dueDate)
            }
            if let paidAt {
                Divider()
                metadataRow("Payment Date", date: paidAt)
            }
        }
        .padding(.vertical, 4)
    }

    private func metadataRow(_ label: LocalizedStringKey, date: Date) -> some View {
        LabeledContent {
            Text(date, format: .dateTime.month(.abbreviated).day().year().locale(locale))
        } label: {
            Text(label)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }
}

private struct InvoiceContactSection: View {
    let title: LocalizedStringKey
    let name: String
    let phone: String?
    let email: String?
    let address: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            Text(name)
                .font(.title3.weight(.semibold))
            if let phone {
                Text(phone)
                    .foregroundStyle(.secondary)
            }
            if let email {
                Text(email)
                    .foregroundStyle(.secondary)
            }
            if let address {
                Text(address)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct InvoiceVisitSection: View {
    let visit: InvoiceVisitDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(visit.visitDate, format: .dateTime.month(.abbreviated).day().year())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(visit.serviceLocationName)
                    .font(.headline)
                if let address = visit.serviceLocationAddress {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 0) {
                Text("Services Provided")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
                Divider()
                ForEach(visit.lineItems) { lineItem in
                    InvoiceLineItemRow(lineItem: lineItem)
                        .padding(.vertical, 16)
                    if lineItem.id != visit.lineItems.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

private struct InvoiceDetailTotal: View {
    let status: InvoiceStatus
    let amount: String

    var body: some View {
        VStack(spacing: SpacingTokens.rowContent) {
            Divider()
            LabeledContent(totalLabel) {
                Text(amount)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
            }
            .font(.headline)
        }
        .padding(.vertical, SpacingTokens.rowContent)
    }

    private var totalLabel: LocalizedStringKey {
        status == .unpaid ? "Amount Due" : "Total"
    }
}

private struct InvoiceTextSection: View {
    let title: LocalizedStringKey
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.rowContent) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, SpacingTokens.rowContent)
    }
}
