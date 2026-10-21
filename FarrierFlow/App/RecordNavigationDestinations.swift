import SwiftData
import SwiftUI

struct RecordNavigationDestinations: ViewModifier {
    @Environment(\.modelContext) private var context
    @Binding var path: NavigationPath

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: ClientRoute.self) { route in
                switch route {
                case .detail(let id):
                    ClientDetailView(clientID: id)
                case .horse(let id):
                    HorseDetailView(horseID: id)
                case .appointment(let id):
                    AppointmentDetailView(appointmentID: id)
                case .visit(let id):
                    VisitDetailView(visitID: id, container: context.container)
                }
            }
            .navigationDestination(for: BarnRoute.self) { route in
                switch route {
                case .list:
                    BarnListView()
                case .detail(let id):
                    BarnDetailView(barnID: id)
                }
            }
            .navigationDestination(for: ServiceRoute.self) { route in
                switch route {
                case .list:
                    ServiceListView()
                case .detail(let id):
                    ServiceDetailView(serviceID: id)
                }
            }
            .navigationDestination(for: BusinessProfileRoute.self) { route in
                switch route {
                case .editor:
                    BusinessProfileEditorView()
                }
            }
            .navigationDestination(for: SubscriptionRoute.self) { route in
                switch route {
                case .store:
                    SubscriptionView(
                        presentation: .standard(
                            showsManageSubscriptionButton: true
                        )
                    )
                }
            }
            .navigationDestination(for: InvoiceRoute.self) { route in
                switch route {
                case .list:
                    InvoiceListView()
                case .history:
                    InvoiceHistoryView(container: context.container)
                case .detail(let id):
                    InvoiceDetailView(invoiceID: id)
                case .create(let clientID):
                    InvoiceCreationView(clientID: clientID) { invoiceID in
                        if path.count > 0 { path.removeLast() }
                        path.append(InvoiceRoute.detail(invoiceID))
                    }
                }
            }
            .navigationDestination(for: BackupSyncRoute.self) { _ in
                BackupSyncView()
            }
            .navigationDestination(for: InvoiceHistoryRoute.self) { route in
                switch route {
                case .list:
                    InvoiceHistoryView(container: context.container)
                case .detail(let identity):
                    InvoiceHistoryDetailView(
                        identity: identity,
                        container: context.container
                    )
                }
            }
    }
}

extension View {
    func recordNavigationDestinations(path: Binding<NavigationPath>) -> some View {
        modifier(RecordNavigationDestinations(path: path))
    }
}
