import SwiftData
import SwiftUI

struct InvoiceListView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @State private var model = InvoiceListModel()
    @State private var hasLocalHistory = false
    @State private var showsHistory = false
    private let filter: InvoiceListFilter

    init(filter: InvoiceListFilter = .all) {
        self.filter = filter
    }

    var body: some View {
        Group {
            switch model.loadState {
            case .loading where model.summaries.isEmpty:
                ProgressView("Loading Invoices…")
            case .failed where model.summaries.isEmpty:
                unavailableContent
            default:
                content
            }
        }
        .farrierFlowScreenBackground()
        .navigationTitle(filter == .unpaid ? Text("Unpaid Invoices") : Text("Invoices"))
        .sheet(isPresented: $showsHistory) {
            InvoiceHistorySheet(container: context.container).dynamicTypeSize(dynamicTypeSize)
        }
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
        .onAppear(perform: reload)
        .onReceive(
            ModelSaveChanges.publisher(in: context.container, entities: [
                "Invoice", "InvoiceVisit", "InvoiceLineItem", "Payment"
            ])
        ) {
            reload()
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.summaries.isEmpty && !hasLocalHistory {
            ContentUnavailableView {
                if filter == .unpaid {
                    Label("No Unpaid Invoices", systemImage: "doc.text")
                } else {
                    Label("No Invoices", systemImage: "doc.text")
                }
            } description: {
                if filter == .unpaid {
                    Text("You have no unpaid invoices.")
                } else {
                    Text("Create an invoice from a client after recording completed work.")
                }
            }
        } else {
            List {
                if hasLocalHistory {
                    Section {
                        if #available(iOS 26, *) {
                            NavigationLink(value: InvoiceRoute.history) { Text(InvoiceHistoryCopy.title) }
                        } else {
                            Button { showsHistory = true } label: { Text(InvoiceHistoryCopy.title) }
                        }
                    } footer: { Text(InvoiceHistoryCopy.notProtected) }
                }
                ForEach(model.summaries) { summary in
                    RecordNavigationLink(value: InvoiceRoute.detail(summary.id)) { InvoiceRow(summary: summary) }
                    .badge(
                        dynamicTypeSize.isAccessibilitySize ? nil : Text(summary.status.displayName)
                            .foregroundStyle(summary.status == .paid ? ColorTokens.success : ColorTokens.textSecondary)
                    )
                    .listRowBackground(ColorTokens.surface)
                }
            }
            .farrierFlowScrollBackground()
        }
    }

    private var unavailableContent: some View {
        ContentUnavailableView {
            Label("Invoices Unavailable", systemImage: "exclamationmark.circle")
        } description: {
            Text("FarrierFlow couldn’t load your invoices. Try again.")
        } actions: {
            Button("Retry", action: reload)
        }
    }

    private func reload() {
        model.load(in: context, locale: locale, filter: filter)
        guard filter == .all else { hasLocalHistory = false; return }
        do { hasLocalHistory = try !InvoiceHistoryArchiveReader(container: context.container).archives().isEmpty }
        catch {
            hasLocalHistory = true
            model.alert = FeatureAlert(title: InvoiceHistoryCopy.title, message: InvoiceHistoryCopy.failure)
        }
    }
}
