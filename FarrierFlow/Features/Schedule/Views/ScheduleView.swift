import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @Environment(\.appClock) private var appClock
    @Environment(\.locale) private var locale
    @State private var path = NavigationPath()
    @State private var model = ScheduleModel()
    @State private var showsEditor = false
    @State private var scope = ScheduleScope.scheduled
    @State private var scheduledServiceID: PersistentIdentifier?
    @State private var completedServiceID: PersistentIdentifier?

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                Picker("Appointment Status", selection: $scope) {
                    Text("Scheduled").tag(ScheduleScope.scheduled)
                    Text("Completed").tag(ScheduleScope.completed)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, SpacingTokens.standard)
                .padding(.vertical, SpacingTokens.compact)
                .accessibilityIdentifier("schedule-status-tabs")
                if model.sections.isEmpty {
                    ContentUnavailableView {
                        Label {
                            if selectedServiceID != nil { Text("No Matching Appointments") }
                            else if scope == .completed { Text("No Completed Appointments") }
                            else { Text("No upcoming appointments") }
                        } icon: { Image(systemName: "calendar") }
                    } description: {
                        if scope == .scheduled, selectedServiceID == nil, subscription.allowsMutations {
                            Text("Use + to schedule work.")
                                .frame(maxWidth: 320)
                        }
                    }
                } else {
                    List {
                        ForEach(model.sections) { section in
                            RecordSection(Text(section.dayStart.formatted(date: .complete, time: .omitted))) {
                                ForEach(section.appointments) { appointment in
                                    RecordNavigationLink(
                                        value: ScheduleRoute.detail(
                                            appointment.id
                                        )
                                    ) {
                                        AppointmentRow(startDate: appointment.startDate, summary: appointment.summary)
                                    }
                                }
                            }
                            .listRowBackground(ColorTokens.surface)
                        }
                    }
                    .listSectionSpacing(.custom(SpacingTokens.standard))
                    .padding(.top, SpacingTokens.compact)
                    .farrierFlowScrollBackground()
                }
            }
            .farrierFlowScreenBackground()
            .navigationTitle("Schedule")
            .toolbarTitleDisplayMode(
                usesLargeTitle ? .inlineLarge : .inline
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Service", selection: serviceSelection) {
                            Text("All Services").tag(PersistentIdentifier?.none)
                            ForEach(model.services) { service in
                                Text(verbatim: serviceFilterTitle(service)).tag(Optional(service.id))
                            }
                        }
                    } label: {
                        Label("Filter by Service", systemImage: selectedServiceID == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityIdentifier("schedule-service-filter")
                }
                if subscription.allowsMutations {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Schedule Appointment", systemImage: "plus") {
                            showsEditor = true
                        }
                    }
                }
            }
            .navigationDestination(for: ScheduleRoute.self) { route in
                switch route {
                case .detail(let id):
                    AppointmentDetailView(appointmentID: id)
                }
            }
            .sheet(isPresented: $showsEditor, onDismiss: reload) {
                AppointmentEditorView { _ in
                    scheduledServiceID = nil
                    scope = .scheduled
                }
            }
            .onAppear(perform: reload)
            .onChange(of: scope) { _, _ in reload() }
            .onReceive(
                ModelSaveChanges.publisher(in: context.container, entities: [
                    "Appointment", "AppointmentHorse", "Barn", "Horse", "Client", "Service", "Visit", "VisitHorse", "WorkItem"
                ])
            ) {
                reload()
            }
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
    }

    private var usesLargeTitle: Bool {
        // Earlier navigation bars overlap a large title with the header outside the List.
        if #available(iOS 26, *) { !dynamicTypeSize.isAccessibilitySize }
        else { false }
    }

    private func serviceFilterTitle(_ service: ServiceChoice) -> String {
        guard model.services.contains(where: { $0.id != service.id && $0.name == service.name }),
              let price = MoneyFormatter.currency(minorUnits: service.defaultAmountMinorUnits,
                  currencyCode: service.currencyCode, locale: locale) else { return service.name }
        return "\(service.name) · \(price)"
    }

    private var selectedServiceID: PersistentIdentifier? {
        scope == .scheduled ? scheduledServiceID : completedServiceID
    }

    private var serviceSelection: Binding<PersistentIdentifier?> {
        Binding(get: { selectedServiceID }, set: { id in
            if scope == .scheduled { scheduledServiceID = id }
            else { completedServiceID = id }
            reload()
        })
    }

    private func reload() {
        model.load(in: context, now: appClock.now(), calendar: .autoupdatingCurrent,
                   scope: scope, serviceID: selectedServiceID)
        if let selectedServiceID, model.alert == nil,
           !model.services.contains(where: { $0.id == selectedServiceID }) {
            if scope == .scheduled { scheduledServiceID = nil }
            else { completedServiceID = nil }
            model.load(in: context, now: appClock.now(), calendar: .autoupdatingCurrent, scope: scope)
        }
    }
}

#Preview("Schedule — Empty") {
    if let container = try? ModelContainerFactory.inMemoryTest() {
        ScheduleView()
            .modelContainer(container)
            .preferredColorScheme(.dark)
    } else {
        ModelContainerFailureView()
    }
}
