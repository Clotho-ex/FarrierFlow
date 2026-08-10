import SwiftUI
import SwiftData

struct ScheduleView: View {
    @Environment(\.modelContext) private var context
    @Environment(SubscriptionAccessModel.self) private var subscription
    @State private var path = NavigationPath()
    @State private var model = ScheduleModel()
    @State private var showsEditor = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if model.sections.isEmpty {
                    ContentUnavailableView {
                        Label("No scheduled appointments", systemImage: "calendar")
                    } description: {
                        Text("Today and future appointments will appear here.")
                    } actions: {
                        if subscription.allowsMutations {
                        Button("Schedule Appointment", systemImage: "plus") {
                            showsEditor = true
                        }
                        }
                    }
                } else {
                    List {
                        ForEach(model.sections) { section in
                            Section(section.dayStart.formatted(date: .complete, time: .omitted)) {
                                ForEach(section.appointments, id: \.persistentModelID) { appointment in
                                    NavigationLink(
                                        value: ScheduleRoute.detail(
                                            appointment.persistentModelID
                                        )
                                    ) {
                                        AppointmentRow(appointment: appointment)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
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
                AppointmentEditorView()
            }
            .onAppear(perform: reload)
            .alert(item: $model.alert) {
                Alert(title: Text($0.title), message: Text($0.message))
            }
        }
    }

    private func reload() {
        model.load(in: context, now: .now, calendar: .autoupdatingCurrent)
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
