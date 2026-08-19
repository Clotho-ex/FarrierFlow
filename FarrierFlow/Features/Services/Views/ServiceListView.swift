import SwiftData
import SwiftUI

struct ServiceListView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var model = ServiceListModel()
    @State private var showsEditor = false

    var body: some View {
        Group {
            switch model.loadState {
            case .loading where model.services.isEmpty:
                ProgressView("Loading Services…")
            case .failed where model.services.isEmpty:
                unavailableContent
            default:
                catalogContent
            }
        }
        .navigationTitle("Services")
        .toolbar {
            if subscription.allowsMutations {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Service", systemImage: "plus") {
                    showsEditor = true
                }
                .accessibilityIdentifier("service-add-action")
            }
            }
        }
        .sheet(isPresented: $showsEditor, onDismiss: reload) {
            ServiceEditorView()
        }
        .onAppear(perform: reload)
    }

    @ViewBuilder
    private var catalogContent: some View {
        if model.services.isEmpty {
            ContentUnavailableView {
                Label("No Services", systemImage: "wrench.and.screwdriver")
            } description: {
                Text("Add the work you charge for, such as a trim or full set.")
            } actions: {
                if subscription.allowsMutations {
                Button("Add Service", systemImage: "plus") {
                    showsEditor = true
                }
                }
            }
        } else {
            List {
                if model.loadState == .failed {
                    Section {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Services Unavailable")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Retry", action: reload)
                        }
                        Text("Some services may not be current. Try loading again.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if model.activeServices.isEmpty {
                    Section("Active") {
                        Text("No active services. Reactivate an archived service or add a new one.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Active") {
                        serviceRows(model.activeServices)
                    }
                }

                if !model.archivedServices.isEmpty {
                    Section("Archived") {
                        serviceRows(model.archivedServices)
                    }
                }
            }
        }
    }

    private var unavailableContent: some View {
        ContentUnavailableView {
            Label("Services Unavailable", systemImage: "exclamationmark.circle")
        } description: {
            Text("FarrierFlow couldn’t load services.")
        } actions: {
            Button("Retry", action: reload)
        }
    }

    @ViewBuilder
    private func serviceRows(_ services: [Service]) -> some View {
        ForEach(services, id: \.persistentModelID) { service in
            NavigationLink(value: ServiceRoute.detail(service.persistentModelID)) {
                ServiceRow(service: service)
            }
        }
    }

    private func reload() {
        model.load(in: context, locale: locale)
    }
}
