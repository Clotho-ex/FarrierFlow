import SwiftData
import SwiftUI

struct InvoiceListView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @State private var model = InvoiceListModel()

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
        .navigationTitle("Invoices")
        .alert(item: $model.alert) {
            Alert(title: Text($0.title), message: Text($0.message))
        }
        .onAppear(perform: reload)
    }

    @ViewBuilder
    private var content: some View {
        if model.summaries.isEmpty {
            ContentUnavailableView {
                Label("No Invoices", systemImage: "doc.text")
            } description: {
                Text("Create an invoice from a client after recording completed work.")
            }
        } else {
            List(model.summaries) { summary in
                NavigationLink(value: InvoiceRoute.detail(summary.id)) {
                    InvoiceRow(summary: summary)
                }
            }
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
        model.load(in: context, locale: locale)
    }
}
